package FeeSumm;

use Data::Dumper;

BEGIN {
	require CSVFile;
	push @ISA , 'CSVFile';
}

use strict;

sub new {
	my $class = shift;

	my $self = $class->SUPER::new ( 
					file				=> undef ,
					headerRecs			=> [] ,
					nonClobRecs			=> [] ,
					nonClobSection		=> undef ,
					nonClobTotSection	=> undef ,
					clobRecs			=> [] ,
					clobSection			=> undef ,
					clobTotSection		=> undef ,
					rtRecs				=> [] ,
					rtSection			=> undef , 
					rtTotSection		=> undef ,
					totSection			=> undef ,
					@_ 
				);
	bless $self;
	
	$self->parse ( $self->{file} );
	
	return $self;
}

sub _parseSection {
	my $self = shift;
	my ( $hdrRec , $recs ) = @_;
	
	my $sectNameRec = shift @$recs;
	my @sectRecs = ( $hdrRec );
	my @sectTotRecs = ( $hdrRec );
	while ( my $rec = shift @$recs ) {
		if ( $$rec[ 0 ] =~ /(Subtotal|Net-)/ ) {
			push @sectTotRecs , $rec;
		}
		else {
			push @sectRecs , $rec;
		}
		last if $$rec[ 0 ] =~ /(^\s*$|Subtotal)/;
	}
	
	my $sect = new CSVFile ( keyFlds => [ $$hdrRec[ 0 ] ] );
	$sect->parseRecs ( \@sectRecs , $self->{file} );

	my $totSect = new CSVFile ( keyFlds => [ $$hdrRec[ 0 ] ] );
	$totSect->parseRecs ( \@sectTotRecs , $self->{file} );
	
	if ( $$sectNameRec[ 0 ] =~ /Non CLOB/ ) {
		$self->{nonClobRecs} = \@sectRecs;
		$self->{nonClobSection} = $sect;
		$self->{nonClobTotSection} = $totSect;
	}
	else {
		$self->{clobRecs} = \@sectRecs;
		$self->{clobSection} = $sect;
		$self->{clobTotSection} = $totSect;
	}
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
	while ( $$recs[ 0 ][ 0 ] !~ /^Description/i ) {
		my $rec = shift @$recs;
		push @{ $self->{headerRecs} } , $rec if $$rec[ 0 ] !~ /^\s*$/;
	}

	my $hdrRec = shift @$recs;	# --- header for all data sections ---

#	Hack for Fee Summ - flesh out all records to the same fld len as the header.
#	----------------------------------------------------------------------------
	foreach my $rec ( @$recs ) {
		foreach ( $#$rec + 1 .. $#$hdrRec ) {
			push @$rec , '';
		}
	}

	while ( $$recs[ 0 ][ 0 ] =~ /^\s*$/ ) {
		shift @$recs;
	}
	
#	The next section is either CLOB (Alpha) or Non-CLOB (TSX/V).
#	------------------------------------------------------------
	$self->_parseSection ( $hdrRec , $recs );
	while ( $$recs[ 0 ][ 0 ] =~ /^\s*$/ ) {
		shift @$recs;
	}
	
#	...and the next section is either CLOB (TSX/V) or Non-CLOB (Alpha).
#	-------------------------------------------------------------------
	$self->_parseSection ( $hdrRec , $recs );
	while ( $$recs[ 0 ][ 0 ] =~ /^\s*$/ ) {
		shift @$recs;
	}

#	Everything after this is RT/VOD/AOD stuff, which we lump together.
#	------------------------------------------------------------------
	my @rtTotRecs = ( $hdrRec );
	push @{ $self->{rtRecs} } , $hdrRec;
	
	while ( @$recs && $$recs[ 0 ][ 0 ] !~ /^Total/ ) {	# --- until the grand total record ---
		my $rec = shift @$recs;
		next if $$rec[ 0 ] =~ /^\s*$/;
		if ( $$rec[ 0 ] =~ /Sub-?total/i ) {
			push @rtTotRecs , $rec;
		}
		else {
			foreach my $fld ( @$rec[ 1 .. $#$rec ] ) {
				if ( $fld =~ /[\d]/ ) {
					push @{ $self->{rtRecs} } , $rec;
					last;
				}
			}
		}
	}
	
	$self->{rtSection} = new CSVFile ( keyFlds => [ $$hdrRec[ 0 ] ] );
	$self->{rtSection}->parseRecs ( $self->{rtRecs} , $self->{file} );
		
	$self->{rtTotSection} = new CSVFile ( keyFlds => [ $$hdrRec[ 0 ] ] );
	$self->{rtTotSection}->parseRecs ( \@rtTotRecs , $self->{file} );
	
	$self->{totSection} = new CSVFile ( keyFlds => [ $$hdrRec[ 0 ] ] );
	$self->{totSection}->parseRecs ( [ $hdrRec , shift @$recs ] , $self->{file} );
}

sub productNetFee {
	my $self = shift;
	my ( $product ) = @_;
	my $useSect;
	foreach my $sect ( $self->{clobTotSection} , $self->{nonClobTotSection} , $self->{rtTotSection} ) {
		if ( grep { $$_{ Description } eq $product } @{ $sect->allKeys () } ) {
			$useSect = $sect;
			last;
		}
	}
	return undef if !$useSect;
	
	my $val = $useSect->val ( { Description => $product } , 'Net Fee' );
	if ( $val ) {
		return $val;
	}
	else {
		return $useSect->val ( { Description => $product } , 'Active/Passive' );
	}
}

sub selfCheck {
	my $self = shift;
	
#	1. Non-CLOB Net fees should sum up to the Non-CLOB Subtotal net fee.
#	--------------------------------------------------------------------
	my $nonClobSumFee = $self->{nonClobSection}->val ( {} , "Net Fee" );
	my $nonClobTotFee = $self->{nonClobTotSection}->val ( {} , "Net Fee" );
	Util::cmpVals ( $nonClobSumFee , $nonClobTotFee , 0.01 , "Non-CLOB Net Fee");
	
#	2. CLOB Active/Passive (TSX/V) or Net (Alpha) fees should sum up to the CLOB Subtotal net fee.
#	----------------------------------------------------------------------------------------------
	my $clobSumFee = $self->{clobSection}->val ( {} , "Active/Passive" );
	if ( !$clobSumFee ) {
		$clobSumFee = $self->{clobSection}->val ( {} , "Net Fee" );
	}
	my $clobTotFeeKey = ( grep { /Sub-?total/i } keys %{ $self->{clobTotSection}->{keyFldMap}->{ Description } } )[ 0 ];
	my $clobTotFee = $self->{clobTotSection}->val ( { Description => $clobTotFeeKey } , "Net Fee" );
	Util::cmpVals ( $clobSumFee , $clobTotFee , 0.01 , "CLOB Net Fee");
	
#	3. If there are Hi/Lo CLOB subtotals, they should equal the sum of their constituents.
#	--------------------------------------------------------------------------------------
	if ( grep { /^Net/ } keys %{ $self->{clobTotSection}->{keyFldMap}->{Description} } ) {
		foreach my $ptrn ( "High CLOB" , "Low CLOB" ) {
			my $sumFee = 0;
			foreach my $keys ( grep { $_->{Description} =~ /$ptrn/ } @{ $self->{clobSection}->allKeys () } ) {
				my $val = $self->{clobSection}->val ( $keys , "Active/Passive" );
				$sumFee += $val;
			}
			my $totFee = $self->{clobTotSection}->val ( { Description => "Net-${ptrn}" } , "Active/Passive" );
			Util::cmpVals ( $sumFee , $totFee , 0.01 , "$ptrn Net Fee");
		}
	}
	
#	4. If there are RT fees, their constituents and subtotals should match up.
#	--------------------------------------------------------------------------

#	5. All sections' totals should sum up to the final grand total.
#	---------------------------------------------------------------
	my $grandSumFee = $nonClobTotFee + $clobTotFee;
	my $rtFee;
	if ( $self->{rtSection} ) {
		foreach my $key ( @{ $self->{rtSection}->allKeys () } ) {
			my $val = $self->{rtSection}->val ( $key , "Net Fee" );
			if ( !$val ) {
				$val = $self->{rtSection}->val ( $key , "Basic Fee" );
			}
			$rtFee += $val;
		}
		$grandSumFee += $rtFee;
	}
	my $grandTotFee = $self->{totSection}->val ( {} , "Net Fee" );
	Util::cmpVals ( $grandSumFee , $grandTotFee , 0.01 , "Overall Total Fee" );
}
	
1;
