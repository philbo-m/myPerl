#!/usr/bin/env perl

use strict;
use Getopt::Long;

use Data::Dumper;

use File::Basename;
use lib dirname $0;

use Util;

use Billing::FeeSumm;
use Billing::AccountSumm;
use Billing::SymbolSumm;
use Billing::TraderAccount;
use Billing::TraderDetail;
use Billing::TraderProductDetail;

sub cmpQtys {
	my ( $qtyKey , $qtyMap ) = @_;
	my %revQtyMap = ();
	foreach my $qtySrc ( keys %$qtyMap ) {
		push @{ $revQtyMap{ sprintf ( "%.2f" , $$qtyMap{ $qtySrc } ) } } , $qtySrc;
	}
	if ( scalar keys %revQtyMap > 1 ) {
		print STDERR "MISMATCH in [$qtyKey]:\n";
		foreach my $qty ( sort { $a <=> $b } keys %revQtyMap ) {
			print STDERR "...[$qty] : [" , join ( " , " , @{ $revQtyMap{ $qty } } ) , "]\n";
		}
	}
}

print STDERR "Reading files...\n";

my %feeFiles = (
	AccountSumm			=> new AccountSumm ( file => glob ( "account_sum*" ) ) ,
	SymbolSumm			=> new SymbolSumm ( file => glob ( "symbol_sum*" ) ) ,
	TraderAccount		=> new TraderAccount ( file => glob ( "trader_account*" ) ) ,
	TraderDetail		=> new TraderDetail ( file => [ glob ( "trader_detail_*clob*" ) ] ) ,
	TraderProductDetail	=> new TraderProductDetail ( file => glob ( "trader_product_detail*" ) )
);


# Check that the FEE SUM file is self-consistent.
# -----------------------------------------------
my $fsFile = new FeeSumm ( file => glob ( "fee_sum*" ) );
print STDERR "Fee Summ Self Check...\n";
$fsFile->selfCheck ();

# Ensure fee distribution is the same among Account Types.
# --------------------------------------------------------
my %acctFeeMap = ();

print STDERR "Acct Type Fee Reconciliation...\n";
my $feeFile = $feeFiles{ "TraderAccount" };
foreach my $acctType ( qw ( CLT PRO RT NX N/C ) ) {
	$acctFeeMap{ "TraderAccount" }{ $acctType } = $feeFile->val ( {} , $acctType );
}

$feeFile = $feeFiles{ "AccountSumm" };
foreach my $acctType ( @{ $feeFile->keys ( "ACCT_TYPE" ) } ) {
	$acctFeeMap{ "AccountSumm" }{ $acctType }{ "BASIC" } = $feeFile->acctTypeBasicFee ( $acctType );
	$acctFeeMap{ "AccountSumm" }{ $acctType }{ "NET" } = $feeFile->acctTypeNetFee ( $acctType );
}

my $asRTBasicFee = $feeFile->subProdBasicFee ( "T_HI_RT" );
my $asRTNetFee = $feeFile->subProdNetFee ( "T_HI_RT" );

foreach my $acctType ( keys %{ $acctFeeMap{ "TraderAccount" } } ) {
	my $taVal = $acctFeeMap{ "TraderAccount" }{ $acctType };
	my $totType = ( $acctType eq 'RT' ? "NET" : "BASIC" );
	my $asVal = $acctFeeMap{ "AccountSumm" }{ $acctType }{ $totType };
#	print STDERR "$acctType,TrdrAcct=$taVal,AcctSumm($totType)=$asVal\n";
	if ( !Util::valMatch ( $taVal , $asVal , 0.01 ) ) {
		print STDERR "MISMATCH IN ACCT TYPE FEE TOTALS\n";
	}
}
	
# Ensure total fees sum up to the same amount.
# --------------------------------------------
my %totFeeMap = ();

print STDERR "Total Fee Reconciliation...\n";
foreach my $file ( keys %feeFiles ) {
	my $totBasicFee = $feeFiles{ $file }->totalBasicFee ();
	my $totNetFee = $feeFiles{ $file }->totalNetFee ();
	
	$totFeeMap{ "BASIC" }{ $file } = $totBasicFee;
	$totFeeMap{ "NET" }{ $file } = $totNetFee;
	
	if ( $file eq 'TraderAccount' && $asRTBasicFee != $asRTNetFee ) {
#		print STDERR "TraderAcct - boosting BASIC total [$totFeeMap{ 'BASIC' }{ $file }] by [$asRTBasicFee] - [$asRTNetFee]...\n";
#		$totFeeMap{ "BASIC" }{ $file } += $asRTBasicFee - $asRTNetFee;
	}
}

foreach my $key ( qw ( BASIC NET ) ) {
	cmpQtys ( $key , $totFeeMap{ $key } );
}

# Ensure fee and volume distribution is the same among Subproducts.
# -----------------------------------------------------------------
my %totValMap = ();

print STDERR "Subproduct Reconciliation...\n";
my $prevSubProdStr = "";
foreach my $file ( keys %feeFiles ) {
	next if $file eq 'TraderAccount';
	my $subProds = $feeFiles{ $file }->keys ( 'PRODUCT' );
	my $subProdStr = join ( "," , sort @$subProds );
	if ( $prevSubProdStr && ( $subProdStr ne $prevSubProdStr ) ) {
		print STDERR "MISMATCH IN SUBPRODUCT LISTS\n";
	}
	$prevSubProdStr = $subProdStr;
	foreach my $subProd ( @$subProds ) {
		$totValMap{ $file }{ $subProd }{ "BASIC" } = $feeFiles{ $file }->subProdBasicFee ( $subProd );
		$totValMap{ $file }{ $subProd }{ "NET" } = $feeFiles{ $file }->subProdNetFee ( $subProd );
		my $totVolKey = ( $file eq 'TraderProductDetail' ? 'TOTAL VOLUME' : 'TOTAL_VOLUME' );
		$totValMap{ $file }{ $subProd }{ "VOL" } = $feeFiles{ $file }->val ( { PRODUCT => $subProd } , $totVolKey );
	}
}

foreach my $key ( qw ( BASIC NET VOL ) ) {
	foreach my $subProd ( split /,/ , $prevSubProdStr ) {
		my %subProdQtyMap = ();
		foreach my $file ( keys %totFeeMap ) {
			next if $file eq 'TraderAccount';
			$subProdQtyMap{ $file } = $totValMap{ $file }{ $subProd }{ $key };
		}
		cmpQtys ( "$subProd $key" , \%subProdQtyMap ); 
	}
}


