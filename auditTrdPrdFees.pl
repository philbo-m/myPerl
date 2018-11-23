#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use Data::Dumper;

use File::Basename;
use lib dirname $0;

use Billing::TraderProduct;
use Billing::TraderProductDetail;

sub valMatch { 
	my ( $v1 , $v2 ) = @_;

	if ( abs ( $v1 ) < 0.05 || abs ( $v2 ) < 0.05 ) {
		return ( abs ( $v1 - $v2 ) < 0.10 );
	}
	else {
		return ( abs ( ( $v1 - $v2 ) / ( $v1 + $v2 ) ) < 0.005 );
	}
}

my %prodMap = (
	T_LO_T1_CLOB		=> "T_LO_CLOB_T1_REG" ,
	T_LO_T2_CLOB		=> "T_LO_CLOB_T2_REG" ,
	T_LO_T1_CLOB_ICE	=> "T_LO_CLOB_ICE_T1" ,
	T_LO_T2_CLOB_ICE	=> "T_LO_CLOB_ICE_T2" ,
	V_LO_CLOB_T1_Reg	=> "V_LO_CLOB_T1_REG" ,
	V_LO_CLOB_T2_Reg	=> "V_LO_CLOB_T2_REG" ,
);
	
# print STDERR "Reading files...\n";

my $tpFile = new TraderProduct ( file => glob ( "trader_product_[0-9]*.csv" ) );
my $tpdFile = new TraderProductDetail ( file => glob ( "trader_product_detail*.csv" ) );

# Grab all the Products in the TraderProduct file.
# ------------------------------------------------
print STDERR "[" , glob ( "trader_product_[0-9]*.csv" ) , "]\n";
open FILE , glob ( "trader_product_[0-9]*.csv" ) or die "Could not open TraderProduct file\n";
chomp ( my $hdr = <FILE> );
close FILE;

$hdr =~ s/"//g;
my @tpProds = split /,/ , $hdr;
shift @tpProds;	pop @tpProds , pop @tpProds; # --- first field is TRADER_ID; last fields are BASIC/NET Fee ---
@tpProds = sort ( @tpProds );

# Make sure the products line up.
# -------------------------------
my $tpdProds = $tpdFile->keys ( 'PRODUCT' );
$tpdProds = [ sort @$tpdProds ];

foreach my $tpProd ( @tpProds ) {
	my $tpcProd = $tpProd;
	if ( exists $prodMap{ $tpProd } ) {
		$tpcProd = $prodMap{ $tpProd };
	}
	my $tpFee = $tpFile->val ( {} , $tpProd );
	my $tpdBasicFee = $tpdFile->val ( { PRODUCT => $tpcProd } , 'BASIC FEE' );
	my $tpdNetFee = $tpdFile->val ( { PRODUCT => $tpcProd } , 'NET_FEE' );
	my $tpdFee = ( $tpProd eq 'T_HI_RT' ? $tpdNetFee : $tpdBasicFee );
#	print STDERR "$tpProd,$tpcProd,$tpFee,$tpdBasicFee,$tpdNetFee\n";
	if ( !valMatch ( $tpFee , $tpdFee ) ) {
		print STDERR "FEE MISMATCH : [$tpProd] [$tpcProd] TP [$tpFee] TPD BASIC [$tpdBasicFee] NET [$tpdNetFee]\n";
	}
}
