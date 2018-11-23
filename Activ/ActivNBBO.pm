package Activ::ActivNBBO;

use strict;
use Data::Dumper;

use Activ::ActivMsg;
use Util;

# Object structure:
#	Self 
#		=> TimeStamp => <time>
#		=> <side>
#			=> Price 			=> <price>
#			=> Size  			=> <size>
#			=> TimeStamp 		=> <time> (time the price was set)
#			=> UpdateTimeStamp	=> <time> (time the last change took place)
#		    => ExchMap
#				=> <exch>
#					[
#						Size		=> <size>
#						TimeStamp	=> <time>
#					] , ... (sorted by TimeStamp, newest first.  Up to 10 of these for Alpha, only 1 for all other ATSs)

sub new {
	my $class = shift;
	my $self = {
					TimeStamp	=> undef
				};			
	
	bless $self;
	for ( qw ( BID ASK ) ) {
		$self->_initSide ( $_ );
	}
	
	return $self;
}

sub _initSide {
	my $self = shift;
	my ( $side ) = @_;
	
	$self->{ $side } = {
		Price			=> undef ,
		Size			=> undef ,
		TimeStamp		=> undef ,
		UpdateTimeStamp	=> undef ,
		ExchMap 		=> {}	
	};
}

sub hdr {
	my @hdr = ();
	foreach ( sort keys %Activ::ActivMsg::exchMap ) {
		my $exch = $Activ::ActivMsg::exchMap{ $_ };
		if ( $_ eq 'ATS' ) {
			foreach my $suffix ( '' , '-1MS','-2MS','-3MS','_MAX' ) {
				push @hdr , $exch . $suffix;
			}
		}
		else {
			push @hdr , $exch;
		}
	}
	return join ( "," , @hdr );
}

sub apply {
	my $self = shift;
	my ( $nbboMsg ) = @_;
	
	$self->{ TimeStamp } = $nbboMsg->getFld ( 'BID_TIME' );
	foreach my $side ( 'BID' , 'ASK' ) {
		$self->{ TimeStamp } = $nbboMsg->getFld ( "${side}_TIME" ) if !$self->{ TimeStamp };
		$self->applySide ( $nbboMsg , $side , $self->{ TimeStamp } );
	}
}

sub applySide {
	my $self = shift;
	my ( $nbboMsg , $side , $timeStamp ) = @_;
	
	my $price = $nbboMsg->getFld ( "${side}_PRICE" );
	if ( !defined $price ) {
		return;
	}
	 
#	If price has changed, clear out the the side and start again.
#	-------------------------------------------------------------
	if ( $price != $self->{ $side }->{ Price } ) {
		$self->_initSide ( $side );
		return if !$price;
		
		$self->{ $side }->{ Price } = $price;
		$self->{ $side }->{ TimeStamp } = $timeStamp;
	}

#	Add the side information by exchange.
#	-------------------------------------	
	my $sideMap = $self->{ $side };
	my $exch = $nbboMsg->getFld ( "${side}_EXCH" );
	$sideMap->{ ExchMap }->{ $exch } = [] if !exists $sideMap->{ ExchMap }->{ $exch };
	
	my $exchMap = $sideMap->{ ExchMap }->{ $exch };
	my $currExchSize = ( $#$exchMap >=0 ? $$exchMap[ 0 ]->{ Size } : 0 );
	my $newExchSize = $nbboMsg->getFld ( "${side}_SIZE" );
	my $sizeDiff = $newExchSize - $currExchSize;
	
	if ( $sizeDiff ) {		
		unshift @$exchMap , { TimeStamp => $timeStamp , Size => $newExchSize };
		my $maxLen = ( $exch eq 'ATS' ? 10 : 1 );
		if ( $#$exchMap >= $maxLen ) {
			pop @$exchMap;
		}
		$sideMap->{ Size } += $sizeDiff;
		$sideMap->{ UpdateTimeStamp } = $timeStamp;
	}
}

sub dump {
	my $self = shift;
	my ( $side , $time ) = @_;
	
	my @volList = ();

	foreach my $exch ( sort keys %Activ::ActivMsg::exchMap ) {
		push @volList , ( $side ? 
							( $exch eq 'ATS' ? 
								$self->getHistNBBOSizes ( $side , $exch , $time ) :
								$self->{ $side }->{ ExchMap }->{ $exch }[ 0 ]->{ Size } 
							) : 
							'' 
						);
	}
	return join ( "," , @volList );
}

sub dumpAll {
	my $self = shift;

	my @nbboSideInfo;
	foreach my $side ( qw ( BID ASK ) ) {
		my $sideMap = $self->{ $side };
		push @nbboSideInfo , ( $side , $sideMap->{ Price } );

		my @nbboExchInfo;
		foreach my $exch ( sort keys %Activ::ActivMsg::exchMap ) {
			my $exchMap = $sideMap->{ ExchMap }->{ $exch };
			if ( $exchMap && $$exchMap[ 0 ]->{ Size } ) {
				push @nbboExchInfo , "$exch=$$exchMap[ 0 ]->{ Size }";
			}
		}
		push @nbboSideInfo , join ( '|' , @nbboExchInfo );
	}
	return join ( "," , $self->{ TimeStamp } , @nbboSideInfo );
}

sub getHistNBBOSizes {
	my $self = shift;
	my ( $side , $exch , $now ) = @_;
	
	my $exchMap = $self->{ $side }->{ ExchMap }->{ $exch };
	
	my @histSizes = ( $$exchMap[ 0 ]->{ Size } );
	my $numHist = $#$exchMap;
	my $histPos = 0;
	my $maxSize = 0;
	my $msAgo = 0;
	while ( $msAgo++ < 3 ) {
		my $ago = $msAgo / 1000;
		while ( $histPos <= $numHist ) {
			if ( Util::timeDiff ( $$exchMap[ $histPos ]->{ TimeStamp } , $now ) >= $ago ) {
				my $size = $$exchMap[ $histPos ]->{ Size };
				push @histSizes , $size;
				$maxSize = $size if $size > $maxSize;
				last;
			}
			$histPos++;
		}
		if ( $histPos > $numHist ) {
#			print STDERR "ERROR - ran out of size history\n";
		}
	}
	push @histSizes , $maxSize;
	return @histSizes;
}

1;

