package CSVFile;

use strict;
no strict 'refs';

use CSV;
use DeepHash;
use Util;

use Data::Dumper;

my $WILDCARD = "*";

sub new {
	my $class = shift;
	my $self = {
		keyFlds 	=> [] , 
		ignoreFlds	=> [] ,
		useHdr		=> 1 ,
		@_
	};

	$self->{keyFldMap} = { map { $_ => {} } @{ $self->{keyFlds} } };
	
	$self->{recs} = [];
	$self->{valMap} = {};
	
	return bless $self;	
}

sub dbg {
	my $dbg = 0;
	print join ( " " , @_ ) , "\n" if $dbg;
}


sub keys {
	my $self = shift;
	my ( $keyFld ) = @_;
	
	return [ keys %{ $self->{keyFldMap}{ $keyFld } } ];
}

sub valKeys {
	my $self = shift;
	
	return [ keys %{ $self->{valMap} } ];
}

sub allKeys {
	my $self = shift;
	
	my @keyMapList = ();
	
#	Any value map will do, as they all have the same key structure.
#	---------------------------------------------------------------
	my $valHash = ( values %{ $self->{valMap} } )[ 0 ];
	foreach my $keys ( @{ $valHash->keys () } ) {
		my %keyMap = ();
		foreach my $i ( 0 .. $#{ $self->{keyFlds} } ) {
			$keyMap{ ${ $self->{keyFlds} }[ $i ] } = $$keys[ $i ];
		}
		push @keyMapList , \%keyMap;
	}
	
	return \@keyMapList;
}

# Usage : val ( { keyFld => keyVal , . . . } , valFld )
# -----------------------------------------------------

sub val {
	my $self = shift;
	my ( $keyFldMap , $valFld ) = @_;
	return undef if !defined $self->{valMap}{ $valFld };
	
	my @keyFldVals = ();
	foreach my $fldName ( @{ $self->{keyFlds} } ) {
		push @keyFldVals , ( defined $$keyFldMap{ $fldName } ? $$keyFldMap{ $fldName } : undef );
	}
	return $self->{valMap}{ $valFld }->val ( \@keyFldVals );
}

sub add {
	my $self = shift;
	my ( $keyFldMap , $valFld , $val ) = @_;
	
#	Convert field map to array.
#	---------------------------
	my @keyFldVals = ();
	foreach my $fldName ( @{ $self->{keyFlds} } ) {
		if ( !exists $$keyFldMap{ $fldName } ) {
			print STDERR "Error : add : key field [$fldName] not specified.\n";
			return;
		}
		push @keyFldVals , $$keyFldMap{ $fldName };
	}
	
	$self->{valMap}{ $valFld }->add ( \@keyFldVals , $val );
}

sub delete {
	my $self = shift;
	my ( $keyFldMap , $valFld ) = @_;
	
#	Convert field map to array.
#	---------------------------
	my @keyFldVals = ();
	foreach my $fldName ( @{ $self->{keyFlds} } ) {
		if ( !exists $$keyFldMap{ $fldName } ) {
			print STDERR "Error : add : key field [$fldName] not specified.\n";
			return;
		}
		push @keyFldVals , $$keyFldMap{ $fldName };
	}
	
	$self->{valMap}{ $valFld }->delete ( \@keyFldVals );
}	

sub parse {
	my $self = shift;
	my ( $file ) = @_;
	
	if ( ref ( $file ) eq 'ARRAY' ) {
		foreach ( @$file ) {
			$self->parse ( $_ );
		}
		return;
	}
	
	local $/;
	
	print STDERR "Parsing [$file]...\n";
	open FILE , $file or die "Cannot open CSV file [$file]: $!";
	my $fileCont = <FILE>;
	close FILE;

	my $recs = CSV::parseRecs ( $fileCont );
	$self->parseRecs ( $recs , $file );
}

sub parseRecs {
	my $self = shift;
	my ( $recs , $fileName ) = @_;

	$self->{fldNameByIdx} = {};
	$self->{fldIdxByName} = {};
	
	my ( %fldIdxByName , %fldNameByIdx );
	
	my %ignoreFldMap = map { $_ => 1 } @{ $self->{ignoreFlds} };

#	Grab the header rec or, if we are not expecting a header rec, just index the columns.
#	-------------------------------------------------------------------------------------
	my $hdrRec;
	if ( $self->{useHdr} ) {
		$hdrRec = shift @$recs;
	}
	else {
		$hdrRec = $$recs[ 0 ];
	}

	my $fldIdx = 0;
	foreach my $fld ( @$hdrRec ) {
		if ( !$self->{useHdr} ) {
			$fld = $fldIdx + 1;
		}
		$self->{fldNameByIdx}{ $fldIdx } = $fld;
		$self->{fldIdxByName}{ $fld } = $fldIdx++;
			
#		Create value hashes named after the header fields (which might be just fld indices).
#		------------------------------------------------------------------------------------
		if ( !exists $ignoreFldMap{ $fld } && !exists $self->{keyFldMap}{ $fld } ) {
#			...not a key fld, not a fld to ignore, must be a value fld...
			if ( !exists $self->{valMap}{ $fld } ) {	# --- might already exist, if we are parsing multiple files ---
				push @{ $self->{valFlds} } , $fld;
				$self->{valMap}{ $fld } = new DeepHash ( Name => $fld );
			}
		}
	}
	
#	Make sure key flds exist.
#	-------------------------
	foreach my $fld ( @{ $self->{keyFlds} } ) {
		if ( !exists $self->{fldIdxByName}{ $fld } ) {
			print STDERR "Error : key fld [$fld] not found in file [$fileName]\n";
			exit 1;
		}
	}

	foreach my $rec ( @$recs ) {
	
		my $fldIdx = 0;
		my ( %keyFldVal , %fldVal );
		
		foreach my $fld ( @$rec ) {
			my $fldName = $self->{fldNameByIdx}{ $fldIdx++ };
			next if ( !$fldName || exists $ignoreFldMap{ $fldName } );
			
			if ( exists $self->{keyFldMap}{ $fldName } ) {
				$keyFldVal{ $fldName } = $fld;
				$self->{keyFldMap}{ $fldName }{ $fld } = 1;
			}
			else {
				$fldVal{ $fldName } = $fld;
			}
		}
		
		my @keyVals = map { $keyFldVal{ $_ } } @{ $self->{keyFlds} };
		
		foreach my $valFld ( keys %fldVal ) {
			my $val = $fldVal{ $valFld };
			$self->{valMap}{ $valFld }->add ( \@keyVals , $val );		
		}
	}

#	Add the records to this object's rec list.
#	------------------------------------------
	push @{ $self->{recs} } , @$recs;
	
}

sub dumpRec {
	my $self = shift;
	my ( $keys , $reverse ) = @_;
	my $mult = ( $reverse ? -1 : 1 );
	
	my $dump = join ( "," , map { $$keys{ $_ } } @{ $self->{keyFlds} } )
				. ","
				. join ( "," , map { $self->val ( $keys , $_ ) * $mult } @{ $self->{valFlds} } );
	return $dump;
}		

sub cmp {
	my $self = shift;
	my ( $other , $args ) = @_;
	my %args = ( $args ? %$args : () );
	my $tabular = $args{ Tabular };
	my $reverseOther = $args{ ReverseOther };
	
#	Cache flattened keys so we can keep track of who's got what keys.
#	-----------------------------------------------------------------
	my ( %selfKeys , %otherKeys );
	foreach my $keys ( @{ $self->allKeys () } ) {
		my $keyStr = join ( "," , map { $$keys{ $_ } } @{ $self->{keyFlds} } );
		$selfKeys{ $keyStr } = 1;
	}
	foreach my $keys ( @{ $other->allKeys () } ) {
		my $keyStr = join ( "," , map { $$keys{ $_ } } @{ $other->{keyFlds} } );
		$otherKeys{ $keyStr } = 1;
	}

#	Compare values associated with matching keys.
#	---------------------------------------------
	foreach my $keys ( sort @{ $self->allKeys () } ) {
		
		my $keyStr = join ( "," , map { $$keys{ $_ } } @{ $self->{keyFlds} } );
		next if !exists $otherKeys{ $keyStr };
	
		delete $selfKeys{ $keyStr };
		delete $otherKeys { $keyStr };
		
		my $isRecDiff;
		my %valDiffMap = ();
		foreach my $valFld ( @{ $self->{valFlds} } ) {
			my $selfVal = $self->val ( $keys , $valFld );
			my $otherVal = $other->val ( $keys , $valFld );
			$valDiffMap{ $valFld } = $selfVal - $otherVal;
			my $isDiff = !Util::valMatch ( $selfVal , $otherVal , 0.001 );
			if ( $isDiff ) {
				$isRecDiff = 1;
				if ( !$tabular ) {
					printf "DIFF,$keyStr,$valFld,%.4f,%.4f,%.4f\n" , $selfVal , $otherVal , $selfVal - $otherVal;
				}
			}
		}
		if ( $isRecDiff && $tabular) {
			print "DIFF,$keyStr," , join ( "," , map { sprintf ( "%.2f" , $valDiffMap{ $_ } ) } @{ $self->{valFlds} } ) , "\n";
		}
	}
	
#	Dump values associated with just this object.
#	---------------------------------------------
	foreach my $keyStr ( sort keys %selfKeys ) {
		my @keyVals = split ( /,/ , $keyStr );
		my %keyHash = ();
		foreach my $i ( 0 .. $#{ $self->{keyFlds} } ) {
			$keyHash{ ${ $self->{keyFlds} }[ $i ] } = $keyVals[ $i ];
		}
		print "THIS," , $self->dumpRec ( \%keyHash ) , "\n";
	}
	
#	Dump values associated with just the other object.
#	--------------------------------------------------
	foreach my $keyStr ( sort keys %otherKeys ) {
		my @keyVals = split ( /,/ , $keyStr );
		my %keyHash = ();
		foreach my $i ( 0 .. $#{ $other->{keyFlds} } ) {
			$keyHash{ ${ $other->{keyFlds} }[ $i ] } = $keyVals[ $i ];
		}
		print "OTHER," , $other->dumpRec ( \%keyHash , $reverseOther ) , "\n";
	}
}	

1;