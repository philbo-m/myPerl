#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use Data::Dumper;

use File::Basename;
use lib dirname $0;

# use Billing::FeeSum;
use Billing::TraderDetail;
use Billing::TSXProdMap;

my @nonClobProds = (
	"TSX Opening Auction" ,
	"TSX Venture Opening Auction" ,
	"MBF" ,
	"TSX MOC" ,
	"TSX Extended Trading" ,
	"TSXV MOC" ,
	"TSXV Extended Trading" ,
	"Settlement Terms" ,
	"TSX Rights/Warrants" ,
	"TSX Notes/Debentures" ,
	"TSX MGF Autofill" ,
	"TSX Exchangeables" ,
	"NEX Trading" ,
	"TSX High Dark" ,
	"TSXV High Dark" ,
	"TSX Low Dark" ,
	"TSXV Low Dark"
);

my @clobProds = (
	"TSX High CLOB",
	"TSX Venture High CLOB",
	"TSX Low CLOB",
	"TSX Venture Low CLOB",
);

my @rtProds = (
	"TSX ETF RT" ,
	"TSX RT" ,
	"TSXV VOD"
);

my @elpProds = (
	"ELP Rebate"
);


# Make an External-to-Internal product map.
# -----------------------------------------
my %extToIntProdMap = map { $TSXProdMap::intToExtProdMap{ $_ } => $_ } keys %TSXProdMap::intToExtProdMap;

# Grab the Trader Detail file contents.
# -------------------------------------
my $tdFile = new TraderDetail ( file => $ARGV[ 0 ] );

foreach my $prod ( @nonClobProds ) {
	my $intProd = $extToIntProdMap{ $prod };
	if ( !$intProd ) {
		print STDERR "ERROR : no internal Product for external Product [$prod]\n";
		next;
	}
	my $totFee = 0;
	foreach my $subProd ( @{ $TSXProdMap::subProdMap{ $intProd } } ) {
		$totFee += $tdFile->val ( { PRODUCT => $subProd } , "NET_FEE" );
	}
	if ( $totFee ) {
		printf "%s,%.2f\n" , $prod , $totFee;
	}
}

foreach my $prod ( @clobProds ) {
	my $intProd = $extToIntProdMap{ $prod };
	if ( !$intProd ) {
		print STDERR "ERROR : no internal Product for external Product [$prod]\n";
		next;
	}
	my ( $totActFee , $totPsvFee ) = ( 0 , 0 );
	foreach my $subProd ( @{ $TSXProdMap::subProdMap{ $intProd } } ) {
		my $netFee = $tdFile->val ( { PRODUCT => $subProd } , "NET_FEE" );
		my $psvCrd = $tdFile->val ( { PRODUCT => $subProd } , "PASSIVE_CREDIT" );
		$totActFee += $netFee - $psvCrd;
		$totPsvFee += $psvCrd;
	}
	if ( $totActFee || $totPsvFee ) {
		printf "%s Active,%.2f\n" , $prod , $totActFee;
		printf "%s Passive,%.2f\n" , $prod , $totPsvFee;
	}
}

foreach my $prod ( ( @rtProds , @elpProds ) ) {
	my $intProd = $extToIntProdMap{ $prod };
	if ( !$intProd ) {
		print STDERR "ERROR : no internal Product for external Product [$prod]\n";
		next;
	}
	my $totFee = 0;
	foreach my $subProd ( @{ $TSXProdMap::subProdMap{ $intProd } } ) {
		$totFee += $tdFile->val ( { PRODUCT => $subProd } , "NET_FEE" );
	}
	if ( $totFee ) {
		printf "%s,%.2f\n" , $prod , $totFee;
	}
}

