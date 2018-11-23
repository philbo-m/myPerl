package PoFeeReconSumm;

use Data::Dumper;

use CSVFile;
use Util;

use strict;

sub new {
	my $class = shift;

	my $self =  { 
					file			=> undef ,
					headerRecs		=> [] ,
					poRecs			=> [] ,
					poSection		=> undef ,
					poTotSection	=> undef ,
					elpRecs			=> [] ,
					elpSection		=> undef , 
					prodRecs		=> [] ,
					prodSection		=> undef ,
					prodTotSection	=> undef ,
					@_ 
				};

	bless $self;
	
	$self->parse ( $self->{file} );
	
	return $self;
}

sub parse {
	my $self = shift;
	my ( $file ) = @_;
	
	local $/ = undef;	# --- grab the entire file ---

	print STDERR "Parsing [$file]...\n";
	open FILE , $file or die "Cannot open Billing file [$file]: $!";
	my $fileCont = <FILE>;
	close FILE;

	my $recs = CSV::parseRecs ( $fileCont );
	
	my @recBuf = ();

#	Grab the header, if any.
#	------------------------
	$self->{headerRecs} = [];
	while ( $$recs[ 0 ][ 0 ] !~ /^Broker/i ) {
		my $rec = shift @$recs;
		push @{ $self->{headerRecs} } , $rec if $$rec[ 0 ] !~ /^\s*$/;
	}

#	Grab and parse the PO section recs.
#	-----------------------------------
	my $poHdrRec = $$recs[ 0 ];
	while ( $$recs[ 0 ][ 0 ] !~ /^\s*$/ ) {
		push @{ $self->{poRecs} } , shift ( @$recs );
	}
	
	$self->{poSection} = new CSVFile ( 
								keyFlds => [ $self->{poRecs}[ 0 ][ 0 ] ] ,
								ignoreFlds => [ $self->{poRecs}[ 0 ][ 1 ] ]
							);
	$self->{poSection}->parseRecs ( $self->{poRecs} , $self->{file} );

#	Grab the PO Total recs, on the way to the next section.
#	-------------------------------------------------------
	my @poTotRecs;
	while ( $$recs[ 0 ][ 0 ] =~ /^\s*$/ ) {
		my $rec = shift @$recs;
		if ( $$rec[ 1 ] !~ /^\s*$/ ) {
			push @poTotRecs , $rec;
		}
	}

	if ( @poTotRecs ) {
		unshift @poTotRecs , $poHdrRec;
		$self->{poTotSection} = new CSVFile (
									keyFlds => [ $$poHdrRec[ 1 ] ] ,
									ignoreFlds => [ $$poHdrRec[ 0 ] ]
								);
		$self->{poTotSection}->parseRecs ( \@poTotRecs , $self->{file} );
	}
	
	if ( $$recs[ 0 ][ 0 ] =~ /ELP/ ) {
	
#		Old file (pre June 2015).  Grab the ELP section.
#		------------------------------------------------
		shift @$recs;
		while ( $$recs[ 0 ][ 0 ] =~ /^\s*$/ ) {
			shift @$recs;
		}
		
		while ( $$recs[ 0 ][ 0 ] !~ /^\s*$/ ) {
			push @{ $self->{elpRecs} } , shift ( @$recs );
		}
		
		$self->{elpSection} = new CSVFile ( 
									keyFlds => [ "BROKER NUMBER" ] ,
									ignoreFlds => [ "BROKER NAME" , "ELP GROUP ID" , "ELP DETAIL" ]
								);
		$self->{elpSection}->parseRecs ( $self->{elpRecs} , $self->{file} );

		while ( $$recs[ 0 ][ 0 ] =~ /^\s*$/ || $$recs[ 0 ][ 0 ] =~ /Grand Total/ ) {
			shift @$recs;
		}
	}
			
#	Grab and parse the Product section recs.  Note the accommodation for the different formats
#	(and header rec) for this section among the various POFEERECONSUM files.
#	------------------------------------------------------------------------------------------
	my $prodTotalRec;
	my $prodHdrRec = $$recs[ 0 ];
	while ( @$recs ) {
		my $rec = shift @$recs;
		
		if ( $$rec[ 0 ] =~ /Total/i ) {
			$prodTotalRec = $rec;
			next;
		}
		elsif ( $$rec[ 0 ] =~ /^\s*$/ ) {
			next;
		}
		push @{ $self->{prodRecs} } , $rec;
	}
		
	my ( $keyFlds , $ignoreFlds );
	if ( $self->{prodRecs}[ 0 ][ 0 ] =~ /DESCRIPTION/i ) {
		$keyFlds = [ $self->{prodRecs}[ 0 ][ 0 ] ];
		$ignoreFlds = [];
	}
	else {
		$keyFlds = [ $self->{prodRecs}[ 0 ][ 1 ] ];
		$ignoreFlds = [ $self->{prodRecs}[ 0 ][ 0 ] ];
	}
	
	$self->{prodSection} = new CSVFile ( 
								keyFlds => $keyFlds ,
								ignoreFlds => $ignoreFlds
							);
	$self->{prodSection}->parseRecs ( $self->{prodRecs} , $self->{file} );	
	
	if ( $prodTotalRec ) {
		$self->{prodTotSection} = new CSVFile ( 
										keyFlds => $keyFlds ,
										ignoreFlds => $ignoreFlds
									);
		$self->{prodTotSection}->parseRecs ( [ $prodHdrRec , $prodTotalRec ] , $self->{file} );	
	}
}

sub feeByPO {
	my $self = shift;
	
	my %feeByPO = ();
	my $poSection = $self->{poSection};
	
#	Identify the PO and Total Fee fields.
#	-------------------------------------
	my $poFld = $poSection->{keyFlds}[ 0 ];
	my $valFld;
	foreach $valFld ( keys %{ $poSection->{valMap} } ) {
		last if $valFld =~ /Grand Total/i;
	}
	
	foreach my $po ( $poSection->keys ( $poFld ) ) {
		$feeByPO{ $po } = $poSection->val ( { $poFld => $po } , $valFld );
	}
	
	return \%feeByPO;
}

sub feeByProd {
	my $self = shift;
	
	my %feeByProd = ();
	my $prodSection = $self->{prodSection};

#	Identify the Product and Total Fee fields.
#	------------------------------------------
	my $prodFld = $prodSection->{keyFlds}[ 0 ];
	my $valFld;
	foreach ( keys %{ $prodSection->{valMap} } ) {
		if ( /Total Fee$/i ) {
			$valFld = $_;
			last;
		}
	}
	
	foreach my $prod ( @{ $prodSection->keys ( $prodFld ) } ) {
		$feeByProd{ $prod } = $prodSection->val ( { $prodFld => $prod } , $valFld );
	}
	
	return \%feeByProd;
}

sub prodList {
	my $self = shift;
	
	my @prodList = ();
	my $prodSection = $self->{prodSection};
	my $recs = $prodSection->{recs};	

#	Identify which field is the Product field.
#	------------------------------------------
	my $fldIdx;
	foreach my $hdrFld ( keys %{ $prodSection->{fldIdxByName} } ) {
		if ( $hdrFld =~ /Description/i ) {
			$fldIdx = $prodSection->{fldIdxByName}{ $hdrFld };
			last;
		}
	}
	foreach my $rec ( @$recs ) {
		push @prodList , $$rec[ $fldIdx ];
	}		
	
	return \@prodList;
}

sub selfCheck {
	my $self = shift;

#	1. For each PO, Sr. and Jr. Mkt Fees should add up to PO's Grand Total.
#	-----------------------------------------------------------------------
	my $poSection = $self->{poSection};
	my $poFld = $poSection->{keyFlds}[ 0 ];
	my ( @mktFlds , $totFld );
	my %feeFldMap = (
		'SR. MARKET TOTAL FEE'	=> "TSX" ,
		'JR. MARKET TOTAL FEE'	=> "TSXV" ,
		'GRAND TOTAL'			=> "TOTAL" ,
		'RT TRADING CREDIT'		=> "RT"
	);
	
	my ( %sumFeeMap , %intFeeMap ) = ();

	foreach my $po ( sort { $a <=> $b } @{ $poSection->keys ( $poFld ) } ) {
		
		my %poFeeMap = ();
		foreach my $fld ( keys %{ $poSection->{valMap} } ) {
			my $feeFld = $feeFldMap{ uc ( $fld ) };
			my $feeVal = $poSection->val ( { $poFld => $po } , $fld );
			$poFeeMap{ $feeFld } = $feeVal;
			$sumFeeMap{ $feeFld } += $feeVal;
			if ( $po == 100 ) {
				$intFeeMap{ $feeFld } = $feeVal;
			}
		}
		
		my $poTotMktFee = $poFeeMap{ 'TSX' } + $poFeeMap{ 'TSXV' };
		Util::cmpVals ( $poFeeMap{ TOTAL } , $poTotMktFee , 0.01 , sprintf ( "PO %03d Total Fee" , $po ) );
	}
	
#	2. POs' Market and Grand Totals should sum up to the overall totals.
#	--------------------------------------------------------------------
	if ( $self->{poTotSection} ) {
		my $poTotSection = $self->{poTotSection};
		
		foreach my $key ( @{ $poTotSection->allKeys () } ) {
			foreach my $fld ( keys %{ $poTotSection->{valMap} } ) {
				my $feeFld = $feeFldMap{ uc ( $fld ) };
				my $totFeeVal = $poTotSection->val ( $key , $fld );
				my $sumFeeVal = $sumFeeMap{ $feeFld };
				if ( $key->{ 'BROKER NAME' } =~ /Brokers/ ) {
					$sumFeeVal -= $intFeeMap{ $feeFld };
				}
				Util::cmpVals ( $sumFeeVal , $totFeeVal , { ABS => 0.01 } , sprintf ( "PO Aggregate Fee:%s:%s" , $key->{ 'BROKER NAME' } , $feeFld ) );
			}
		}
	}

#	3. Product fees, grouped into TSX/TSXV/RT, should sum up to the same totals as the PO fees.
#	-------------------------------------------------------------------------------------------
	my $prodSection = $self->{prodSection};
	my $prodKeyFld = $prodSection->{keyFlds}[ 0 ];
	
	my %prodFeeByType = ();
	foreach my $key ( @{ $prodSection->keys ( $prodKeyFld ) } ) {
		my $feeType;
		if ( $key =~ / RT / ) {
			$feeType = 'RT';
		}
		elsif ( $key =~ / VOD / ) {
			$feeType = 'VOD';
		}
		elsif ( $key =~ /Monthly/ ) {
			$feeType = 'SVC';
		}
		elsif ( $key =~ /^TSX / ) {
			$feeType = 'TSX';
		}
		elsif ( $key =~ /^(TSXV|NEX) / ) {
			$feeType = 'TSXV';
		}
		else {
			print STDERR "Unknown product [$key]..\n";
		}
		foreach my $valKey ( @{ $prodSection->valKeys () } ) {
			$prodFeeByType{ $feeType }{ $valKey } += $prodSection->val ( { $prodKeyFld => $key } , $valKey );
#			print STDERR "...adding [$valKey] = [" , $prodSection->val ( { $prodKeyFld => $key } , $valKey ) , "]\n";
		}
	}
	
#	... if there is a product total record, it should be consistent with the individual product records...
	if ( $self->{prodTotSection} ) {
		my $prodTotSection = $self->{prodTotSection};
		foreach my $valKey ( @{ $prodSection->valKeys () } ) {
			my $prodSumVal = $prodFeeByType{ 'TSX' }{ $valKey } 
								+ $prodFeeByType{ 'TSXV' }{ $valKey }
								+ $prodFeeByType{ 'SVC' }{ $valKey };
			my $prodTotVal = $prodTotSection->val ( {} , $valKey );
			Util::cmpVals ( $prodSumVal , $prodTotVal , { ABS => 0.01 } , 
							sprintf ( "Product Aggregate Fee:%s" , $valKey ) );
		}
	}
	
	foreach my $valKey ( @{ $prodSection->valKeys () } ) {
		foreach my $feeType ( keys %sumFeeMap ) {
			next if !exists $prodFeeByType{ $feeType };

#			PO TSX fees = PROD TSX + RT fees
#			PO TSXV fees = PROD TSXV + VOD fees
#			PO RT fees = PROD RT + VOD fees
#			-----------------------------------
			my $prodSumFee = $prodFeeByType{ $feeType }{ $valKey };
			if ( $feeType eq 'TSX' ) {
				$prodSumFee += $prodFeeByType{ 'RT' }{ $valKey };
			}
			elsif ( $feeType eq 'TSXV' ) {
				$prodSumFee += $prodFeeByType{ 'VOD' }{ $valKey };
			}
			elsif ( $feeType eq 'RT' ) {
				$prodSumFee += $prodFeeByType{ 'VOD' }{ $valKey };
			}
			
			my $poSumFee = $sumFeeMap{ $feeType };
			if ( $valKey =~ /BROKER/i ) {
				$poSumFee -= $intFeeMap{ $feeType };
			}
			Util::cmpVals ( $prodSumFee , $poSumFee , { ABS => 0.01 } , 
							sprintf ( "Product vs PO Aggregate Fee:%s:%s" , $valKey , $feeType ) );
		}
	}	
}
	
1;
