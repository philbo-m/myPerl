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
	if ( $side eq 'ASK' && !$refPrice ) {
		$refPrice = 99999;
	}
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
	print STDERR $$nbboMap{ $sym }->dumpAll () , "\n";
}

sub showTrade {
	my ( $nbboMap , $trdMsg ) = @_;
	
	my $exch = $trdMsg->getFld ( "TRD_EXCH" );
#	return if ( $exch ne 'ATS' && $exch ne 'CX2' );
	
	my $sym = $trdMsg->getFld ( 'SYMBOL' );
	my $price = $trdMsg->getFld ( 'TRD_PRICE' );
	my $size = $trdMsg->getFld ( 'TRD_SIZE' );
	
	my $nbbo = $nbboMap->{ $sym };
	if ( !$nbbo ) {
		$nbbo = new Activ::ActivNBBO;	# --- catch the odd case where we get a TRD before an NBBO ---
	}
	
	my ( $priceCmp , $side );
	for ( 'BID' , 'ASK' ) {
		$priceCmp = isBetterPrice ( $price , $nbbo->{ $_ }->{ Price } , $_ );
		if ( $priceCmp >= 0 ) {
			$side = $_;
			last;
		}
	}
	my $where = ( $priceCmp < 0 ? "INSIDE NBBO" :
					( $priceCmp > 0 ? "OUTSIDE " : "AT " ) . $side
				);

	print STDERR join ( "," , (
					$trdMsg->dump () ,
					$where ,
					$nbbo->dump ( $side , $trdMsg->getFld ( 'TRD_TIME' ) ) 
				)
			) , "\n";
}
				
my %nbboMap = ();

my $activFile = new Activ::ActivFile ( File => $ARGV[ 0 ] , maxBuf => 1000 );

print STDERR join ( "," , (
				Activ::ActivTradeMsg::hdr () ,
				"SIDE" ,
				Activ::ActivNBBO::hdr ()
			)
		) , "\n";
while ( my $activMsg = $activFile->next () ) {
	if ( $activMsg->isa ( "Activ::ActivNBBOMsg" ) ) {		
		addToNBBO ( \%nbboMap , $activMsg );
	}
	elsif ( $activMsg->isa ( "Activ::ActivTradeMsg" ) ) {
		showTrade ( \%nbboMap , $activMsg );
	}
}
