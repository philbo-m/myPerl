package FIXMsg;

use strict;
use FIXFld;

my %ignoreCmpFlds = map { $_ => 1 } qw ( 9 34 52 11 10 41 );

my %revTagMap = map { $FIXFld::tagMap{ $_ } => $_ } keys %FIXFld::tagMap;

sub new {
	my $class = shift;
	my $self = {
		delim		=> "" ,
		simple		=> 0 ,
		showTags	=> undef ,
		filter		=> undef ,
		@_
	};

	$self->{delim} =~ s/([\^])/\\$1/g;

	if ( $self->{showTags} ) {
		$self->{showTagMap} = {};
		foreach my $tag ( @{ $self->{showTags} } ) {
			if ( exists $revTagMap{ $tag } ) {
				$tag = $revTagMap{ $tag };
			}
			$self->{showTagMap}{ $tag } = 1;
		}
	}		
			
	bless $self;
	$self->init;
	
	return $self;
}

sub init {
	my $self = shift;

	$self->{raw} = '';
	$self->{isInbound} = undef;
	$self->{timeStamp} = undef;
	$self->{session} = undef;
	$self->{flds} = ();
	$self->{fldMap} = ();
}

sub desc {
	my $self = shift;
	
	if ( !$self->{desc} ) {
		$self->{desc} = ( $self->{timeStamp} ? "$self->{timeStamp} : " : "" ) 
						. ( $self->{isInbound} ? "Receiving" : "Sending" ) . " "
						. $self->msgType;
	}
	return $self->{desc};
}

sub fldVal {
	my $self = shift;
	my ( $tag ) = @_;
	
	if ( exists $revTagMap{ $tag } ) {
		$tag = $revTagMap{ $tag };
	}
	my $fld = $self->{fldMap}{ $tag };
	return ( $fld ? $fld->{val} : undef );
}

sub msgType {
	my $self = shift;
	
	if ( !$self->{msgType} ) {
		my $msgTypeFld = $self->{fldMap}{ 35 };
		if ( $msgTypeFld ) {
			$self->{msgType} = $self->{fldMap}{ 35 }->descVal;
			if ( exists $self->{fldMap}{ 150 } ) {
				$self->{msgType} .= "/" . $self->{fldMap}{ 150 }->descVal;
			}
		}
	}
	return $self->{msgType};
}

sub parse {
	my $self = shift;
	my ( $rec ) = @_;
	
	$self->{raw} = $rec;
	
	my ( $header , $msg ) = ( $rec =~ /^(.*) : (.*)$/ );
	$msg = $rec if !$msg;
	
#	my ( $header , $direction , $msg ) = ( $rec =~ /^(.*)\s+(Sending|Receiving)\s*:\s*(.*)$/ );
#	( $msg = $rec ) =~ s/^.* : //;

	if ( $header =~ /(\d{2}:\d{2}:\d{2}\.[\d_]+)/ ) {
		( $self->{timeStamp} = $1 ) =~ s/_//g;
		$self->addFld ( "TimeStamp" , $self->{timeStamp} );
	}

	( my $session = $header ) =~ s/^.*\[([^]]+)\].*$/$1/;
	$self->addFld ( "Session" , $session );
	
#	$self->{isInbound} = ( $direction eq 'Receiving' );
	$self->{isInbound} = ( $header =~ /INPUT/ );	# --- MIT SOR specific! ---

	( $self->{simple} ? $self->parseSimple ( $msg ) : $self->parseDelim ( $msg ) );
}

sub filter {
	my $self = shift;
	my ( $filter ) = @_;
	if ( !scalar keys %$filter ) {
		return 1;
	}
	foreach my $tag ( keys %$filter ) {
		my $fld = $self->{fldMap}{ $tag };
		if ( !$fld ) {
			return 0;
		}
		if ( exists $$filter{ $tag }{ '*' } ) {
			next;
		}
		if ( !exists $$filter{ $tag }{ $fld->{val} } ) {
			return 0;
		}
	}
	return 1;
}

sub addFld {
	my $self = shift;
	my ( $tag , $val ) = @_;
	if ( !defined $val ) {
		( $tag , $val ) = split /=/ , $tag;
	}

	my $fld = new FIXFld ( $tag , $val );	# --- $fld->{tag} might not wind up the same as $tag ---
	if ( ( !scalar keys %{ $self->{showTagMap} } || exists $self->{showTagMap}{ $fld->{tag} } )
			|| !defined $val ) {
		push @{ $self->{flds} } , $fld;
		${ $self->{fldMap} }{ $fld->{tag} } = $fld;
		
		if ( !$self->{timeStamp} && $fld->{timeStamp} ) {
			$self->{timeStamp} = $fld->{timeStamp};
		}
	}
}
	
sub parseSimple {
	my $self = shift;
	my ( $recs ) = @_;

	foreach my $rec ( split /\n/ , $recs ) {
		chomp $rec;
		$self->addFld ( $rec );
	}
}

sub parseDelim {
	my $self = shift;
	my ( $rec ) = @_;

	if ( $rec !~ /$self->{delim}/ ) {
		$self->addFld ( $rec , undef );
		return;
	}

	$rec =~ s/\|$//;
	my @rec = split ( /(?:$self->{delim}|^)(\d+)=/ , $rec );

	for ( my $idx = 1 ; $idx < $#rec ; $idx += 2 ) {
		$self->addFld ( $rec[ $idx ] , $rec[ $idx + 1 ] );
	}
}

sub isToMkt {
	my $self = shift;
	
	return $self->{fldMap}{ 35 }->isToMkt;
}
	
sub cmp {
	my $self = shift;
	my ( $otherMsg , $ignoreTrailingZeros , $ignoreFldMap ) = @_;
	my @result = ();
	
	foreach my $fld ( @{ $self->{flds} } ) {
		next if exists $$ignoreFldMap{ $fld->{tag} };
		
		my $otherFld = $otherMsg->{fldMap}{ $fld->{tag} };
		if ( !$otherFld ) {
			push @result , [ $fld->desc , $fld->descVal , undef ];
#			print STDERR $self->desc , " : Fld [" , $fld->dump , "] missing in 2nd msg\n";
		}
		elsif ( !exists $ignoreCmpFlds{ $fld->{tag} } 
				&& $fld->cmp ( $otherFld , $ignoreTrailingZeros ) ) {
#			print STDERR $self->desc , " : Flds differ:  [" , $fld->dump , "] [" , $otherFld->dump , "]\n";
			push @result , [ $fld->desc , $fld->descVal , $otherFld->descVal ];
		}
	}
	foreach my $tag ( keys %{ $otherMsg->{fldMap} } ) {
		next if exists $$ignoreFldMap{ $tag };
		
		if ( !exists $self->{fldMap}{ $tag } ) {
			push @result , [ $otherMsg->{fldMap}{ $tag }->desc , undef , $otherMsg->{fldMap}{ $tag }->descVal ];
#			print STDERR $self->desc , " : Fld [" , $otherMsg->{fldMap}{ $tag }->dump , "] missing in 1st msg\n";
		}
	}
	return \@result;
}

sub uniqId {
	my $self = shift;
	
	if ( !$self->{uniqId} ) {
		$self->{uniqId} = $self->fldVal ( 11 );
	}
	
	return $self->{uniqId};
}

sub isRMSReject {
	my $self = shift;
	
	if ( !defined $self->{isRMSReject} ) {
		my $msgType = $self->fldVal ( 35 );
		my $execType = $self->fldVal ( 150 );
		if ( $msgType eq '3' || $msgType eq '9' 					# --- Reject or Cancel Reject ---
				|| ( $msgType eq '8' && $execType eq '8' ) 			# --- Exec Rpt / Rejected ---
		) {		
			my $rejectText = $self->fldVal ( 58 );
			$self->{isRMSReject} = ( 
				$rejectText =~ /Expressway/ 					# --- Mantara ---
				|| $rejectText =~ /Destination is unavailable/	# --- ULLINK ---
			);
		}
	}
	return $self->{isRMSReject};
}

sub dump {
	my $self = shift;
	my ( $showUniqId , $tabular ) = @_;
	
	my @strs = ();
	if ( $showUniqId ) {
		push @strs , "UniqId = " . $self->uniqId;
	}
	
	my $fldList;
	if ( !$tabular ) {
		$fldList = $self->{flds};
	}
	else {
		$fldList = [];
		foreach my $tag ( @{ $self->{showTags} } ) {
			$tag = $revTagMap{ $tag } if defined $revTagMap{ $tag };
			push @$fldList , $self->{fldMap}{ $tag };
		}
	}
	foreach my $fld ( @$fldList ) {
		push @strs , ( $fld ? $fld->dump ( $tabular ) : "" );
	}
	
	my $delim = ( $tabular ? "," : "\n" );
	
	return ( $self->{timeStamp} ? "$self->{timeStamp}$delim" : "" )
			. ( $tabular ? "" : $self->desc . "\n" )
			. join ( $delim , @strs )
			. ( $tabular ? "" : "\n" );
}

1;

__DATA__

sub parseNoDelim {

	while ( <> ) {
		chomp;
		my ( $pfx , $msg ) = /(.*) (.*)$/;
		my @valFlds = split /=/ , $msg;
		my $fldId = shift @valFlds;
		my $lastVal = pop @valFlds;
		
		my %msgTagMap = ();

		for ( my $idx = 0 ; $idx < scalar @valFlds - 1 ; $idx++ ) {
			my $valFld = $valFlds[ $idx ];

			my $nextFldId = '';
			my $fldIdChar;

			while ( $valFld ne '' ) {
			
				$msgTagMap{ $fldId } = 1;

#				Shortcut for time fields, that we know the format of..
#				------------------------------------------------------	
				my $fldPtrn = $fldPtrnMap{ $fldId };
#				print "[$fldId] [$valFld] [$fldPtrn]\n";
				if ( $fldPtrn && $valFld =~ /($fldPtrn)(.+)/ ) {
					print "*** [$fldId] [$valFld] [$fldPtrn]\n";
					( $valFld , $fldIdChar ) = ( $1 , $2 );
				}
				else {
					( $valFld , $fldIdChar ) = ( $valFld =~ /(.*)(.)/ );
				}
				$nextFldId = $fldIdChar . $nextFldId;
				
#				We have pulled a valid fieldID off the end of this msg fragment if:
#				- we know it
#				- we haven't already encountered it
#				- if it has a regexp associated with it, the NEXT fragment matches that regexp
#				------------------------------------------------------------------------------			
				if ( exists $tagMap{ $nextFldId } 
						&& !exists $msgTagMap{ $nextFldId } 
						&& ( !exists $fldPtrnMap{ $nextFldId } || $valFlds[ $idx + 1 ] =~ /^$fldPtrnMap{ $nextFldId }/ ) ) {
			
#					One last check for 67xx and 77xx fieldID scenarios.
#					---------------------------------------------------
					if ( $valFld =~ /(.*)([67]\d)$/ ) {
						if ( exists $tagMap{ $2 . $nextFldId } && !exists $msgTagMap{ $2 . $nextFldId } ) {
							$valFld = $1;
							$nextFldId = $2 . $nextFldId;
						}
					}
					last;
				}
			}
			if ( !%showFlds || exists ( $showFlds{ $fldId } ) ) {
				print descFldVal ( $fldId , $valFld ) , "\n";
			}
			$fldId = $nextFldId;
		}
		if ( !%showFlds || exists ( $showFlds{ $fldId } ) ) {
			print descFldVal ( $fldId , $lastVal ) , "\n";
		}
		print "\n";
	}
}	

1;
