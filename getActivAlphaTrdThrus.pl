#!c:/perl/bin/perl

use strict;
use Data::Dumper;

use Activ::ActivFile;
use Activ::ActivNBBO;
	
sub timeDiff {
	my ( $time1 , $time2 ) = @_;
	my ( $h1 , $m1 , $s1 ) = split ( /:/ , $time1 );
	my ( $h2 , $m2 , $s2 ) = split ( /:/ , $time2 );
	return ( ( $h2 - $h1 ) * 3600 ) + ( ( $m2 - $m1 ) * 60 ) + ( $s2 - $s1 );
}

sub isBetterPrice {

#	Returns 1 if price is better (more aggressive) than ref price,
#	0 if equal, -1 if worse
#	--------------------------------------------------------------
	my ( $price , $refPrice , $side ) = @_;
	my $cmp = ( $price <=> $refPrice );
	return ( $side eq 'BID' ? -$cmp : $cmp );
}

sub addToNBBO  {
	my ( $nbboMap , $nbboMsg ) = @_;
	
	my $sym = $nbboMsg->getFld ( 'SYMBOL' );
	if ( !exists $$nbboMap{ $sym } ) {
		$$nbboMap{ $sym } = new Activ::ActivNBBO;
	}
	$$nbboMap{ $sym }->apply ( $nbboMsg );
}

sub showTrade {
	my ( $nbboMap , $trdMsg ) = @_;
	
	my $exch = $trdMsg->getFld ( "TRD_EXCH" );
	return if $exch eq 'ATS';	# --- Non-Alpha trades only ---
	
	my $sym = $trdMsg->getFld ( 'SYMBOL' );
	my $trdPrice = $trdMsg->getFld ( 'TRD_PRICE' );

	my $nbbo = $nbboMap->{ $sym };
	
	my ( $priceCmp , $side );
	foreach ( 'BID' , 'ASK' ) {
		if ( isBetterPrice ( $trdPrice , $nbbo->{ $_ }->{ Price } , $_ ) > 0
				&& exists $nbbo->{ $_ }->{ ExchMap }->{ ATS } ) {
		
#			Traded through a better price on Alpha.
#			---------------------------------------
			$side = $_;
			last;
		}
	}

	if ( $side ) {
		my ( $poFld , $trdSide );
		if ( $side eq 'BID' ) {
			$poFld = 'TRD_SELLER';
			$trdSide = 'SELL';
		}
		else {
			$poFld = 'TRD_BUYER';
			$trdSide = 'BUY';
		}
		print join ( "," , 
						$trdMsg->getFld ( 'TRD_DATE' ) , 
						$trdMsg->timeStamp () ,
						$sym ,
						$trdMsg->getFld ( $poFld ) ,
						$trdSide ,
						$trdMsg->getFld ( 'TRD_SIZE' ) ,
						$trdPrice ,
						$trdMsg->getFld ( 'TRD_EXCH' ) ,
						$nbbo->{ $side }->{ Price } ,
						$nbbo->{ $side }->{ ExchMap }->{ ATS }[ 0 ]->{ Size }
					) , "\n";
	}
}
				
my %nbboMap = ();

my $activFile = new Activ::ActivFile ( File => $ARGV[ 0 ] , maxBuf => 100000 );

print join ( "," , qw ( Date Time Symbol PO Side Qty Price Exch ATSQuote ATSVol ) ) , "\n";
		
while ( my $activMsg = $activFile->next () ) {
	
	if ( $activMsg->isa ( "Activ::ActivNBBOMsg" ) ) {
		addToNBBO ( \%nbboMap , $activMsg );
	}
	elsif ( $activMsg->isa ( "Activ::ActivTradeMsg" ) ) {
		showTrade ( \%nbboMap , $activMsg );
	}
}
