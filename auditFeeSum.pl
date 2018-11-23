#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use Data::Dumper;

use File::Basename;
use lib dirname $0;

use Billing::FeeSumm;
use Billing::AccountSumm;
use Billing::TSXProdMap;

sub valMatch { 
	my ( $v1 , $v2 ) = @_;
	
	if ( abs ( $v1 ) < 0.05 || abs ( $v2 ) < 0.05 ) {
		return ( abs ( $v1 - $v2 ) < 0.10 );
	}
	else {
		return ( abs ( ( $v1 - $v2 ) / ( $v1 + $v2 ) ) < 0.005 );
	}
}

# Read the Fee Summary file.
# --------------------------
my $fsFile = new FeeSumm ( file => glob ( "fee_sum*.csv" ) , includeTotals => 1 );

# Read the Account Summary file.
# ------------------------------
my $asFile = new AccountSumm ( file => glob ( "account_sum*.csv" ) );

my %extToIntProdMap = map { $TSXProdMap::intToExtProdMap{ $_ } => $_ } keys %TSXProdMap::intToExtProdMap;

my ( $fsRTVal , $asRTVal , $fsVODVal , $asVODVal , $fsNonClobTotal );
my @nonProdItems = ();

foreach my $prod ( @{ $fsFile->keys ( 'Description' ) } ) {
	my $intProd = $extToIntProdMap{ $prod };
	if ( !$intProd ) {
		push @nonProdItems , $prod;
	}
	else {
		my $fsVal = $fsFile->val ( { Description => $prod } , 'Net Fee' );
		my $asVal = 0;
		foreach my $subProd ( @{ $TSXProdMap::subProdMap{ $intProd } } ) {
			$asVal += $asFile->val ( { PRODUCT => $subProd } , 'NET_FEE' );
		}

#		--- Accumulate some totals ---
#		--- Treat RT and ETF RT specially - by combining them ---
		if ( $prod =~ / RT/ ) {
			$fsRTVal += $fsVal;
			$asRTVal += $asVal;
			next;
		}
#		--- Also treat VOD specially ---
		elsif ( $prod =~ / VOD/ ) {
			$fsVODVal += $fsVal;
			$asVODVal += $asVal;
			next;
		}
		
		elsif ( $prod !~ / CLOB/ ) {
			$fsNonClobTotal += $fsVal;
		}
		
		if ( !valMatch ( $fsVal , $asVal ) ) {
			print "$prod,$fsVal,$asVal\n";
		}
	}
}

# --- Compare RT/VOD totals ---
if ( !valMatch ( $fsRTVal , $asRTVal ) ) {
	print "TSX RT,$fsRTVal,$asRTVal\n";
}
if ( !valMatch ( $fsVODVal , $asVODVal ) ) {
	print "TSX RT,$fsRTVal,$asRTVal\n";
}
# --- Check self consistency of non-CLOB fees and the Total Non CLOB line item ---
my $fsNonClobVal = $fsFile->val ( { Description => 'Non-CLOB Subtotal' } , 'Net Fee' );
if ( !valMatch ( $fsNonClobVal , $fsNonClobTotal ) ) {
	print "NON CLOB TOTAL,$fsNonClobTotal,$fsNonClobVal\n";
}

my %fsHiLoClobTotals = ();
my $fsClobTotal;
foreach my $prod ( @nonProdItems ) {
	if ( $prod =~ /(TSX|TSX Venture) (High|Low) CLOB (Active|Passive)/ ) {
		my ( $mkt , $hiLo , $actPsv ) = ( $1 , $2 , $3 );
		$actPsv = uc ( $actPsv ) . '_' . ( $actPsv eq 'Active' ? 'FEE' : 'CREDIT' );
		my $intProd = $extToIntProdMap{ "$mkt $2 CLOB" };
		my $fsVal = $fsFile->val ( { Description => $prod } , 'Active/Passive' );
		my $asVal = 0;
		foreach my $subProd ( @{ $TSXProdMap::subProdMap{ $intProd } } ) {
		
#			--- Special handling for corrections - use NET FEE instead of ACTIVE FEE ---
			my $valKey = ( $subProd =~ /_CORR/ && $actPsv =~ /ACTIVE/ ? 'NET_FEE' : $actPsv );
			$asVal += $asFile->val ( { PRODUCT => $subProd } , $valKey );
#			print STDERR "Adding to [$prod] [$subProd] [" , $asFile->val ( { PRODUCT => $subProd } , $valKey ) , "] -> [$asVal]...\n";
		}
		
		if ( !valMatch ( $fsVal , $asVal ) ) {
			print "$prod,$fsVal,$asVal\n";
		}
		
		my $netKey = "Net-${hiLo} CLOB";
		$fsHiLoClobTotals{ $netKey } += $fsVal;
		$fsClobTotal += $fsVal;
	}
}

# --- Check self-consistency of CLOB fees and the CLOB subtotal and total line items. ---
foreach my $key ( keys %fsHiLoClobTotals ) {
	my $subTotal = $fsHiLoClobTotals{ $key };
	my $lineItemTotal = $fsFile->val ( { Description => $key } , 'Active/Passive' );
	if ( !valMatch ( $subTotal , $lineItemTotal ) ) {
		print "$key,$lineItemTotal,$subTotal\n";
	}
}
my $key = 'CLOB Subtotal';
my $lineItemTotal = $fsFile->val ( { Description => $key } , 'Net Fee' );
if ( !valMatch ( $fsClobTotal , $lineItemTotal ) ) {
	print "$key,$lineItemTotal,$fsClobTotal\n";
}


my $tsxHiClobAct = $fsFile->val ( { Description => 'TSX High CLOB Active' } , 'Active/Passive' );
my $tsxHiClobPsv = $fsFile->val ( { Description => 'TSX High CLOB Passive' } , 'Active/Passive' );
my $tsxLoClobAct = $fsFile->val ( { Description => 'TSX Low CLOB Active' } , 'Active/Passive' );
my $tsxLoClobPsv = $fsFile->val ( { Description => 'TSX Low CLOB Passive' } , 'Active/Passive' );
my $tsxvHiClobAct = $fsFile->val ( { Description => 'TSX Venture High CLOB Active' } , 'Active/Passive' );
my $tsxvHiClobPsv = $fsFile->val ( { Description => 'TSX Venture High CLOB Passive' } , 'Active/Passive' );
my $tsxvLoClobAct = $fsFile->val ( { Description => 'TSX Venture Low CLOB Active' } , 'Active/Passive' );
my $tsxvLoClobPsv = $fsFile->val ( { Description => 'TSX Venture Low CLOB Passive' } , 'Active/Passive' );
my $hiNet = $fsFile->val ( { Description => 'Net-High CLOB' } , 'Active/Passive' );
my $loNet = $fsFile->val ( { Description => 'Net-Low CLOB' } , 'Active/Passive' );

my ( $asTSXHiClobAct , $asTSXHiClobPsv , $asTSXHiClobTot , $asTSXLoClobAct , $asTSXLoClobPsv , $asTSXLoClobTot );
my ( $asTSXVHiClobAct , $asTSXVHiClobPsv , $asTSXVHiClobTot , $asTSXVLoClobAct , $asTSXVLoClobPsv , $asTSXVLoClobTot );
my ( $asTSXHiPS , $asTSXLoPS , $asTSXVHiPS , $asTSXVLoPS );

foreach my $subProd ( grep { /T_HI_CLOB/ } @{ $asFile->keys ( 'PRODUCT' ) } ) {
	my $actFee = $asFile->val ( { PRODUCT => $subProd } , 'ACTIVE_FEE' );
	my $psvFee = $asFile->val ( { PRODUCT => $subProd } , 'PASSIVE_CREDIT' );
	my $totFee = $asFile->val ( { PRODUCT => $subProd } , 'BASIC_FEE' );
	$asTSXHiClobAct += ( $subProd =~ /_CORR/ ? $totFee : $actFee );
	$asTSXHiClobPsv += $psvFee;
	$asTSXHiClobTot += $totFee;
	$asTSXHiPS += $psvFee if $subProd =~ /_PS/;
}
foreach my $subProd ( grep { /T_LO_CLOB/ } @{ $asFile->keys ( 'PRODUCT' ) } ) {
	my $actFee = $asFile->val ( { PRODUCT => $subProd } , 'ACTIVE_FEE' );
	my $psvFee = $asFile->val ( { PRODUCT => $subProd } , 'PASSIVE_CREDIT' );
	my $totFee = $asFile->val ( { PRODUCT => $subProd } , 'BASIC_FEE' );
	$asTSXLoClobAct += ( $subProd =~ /_CORR/ ? $totFee : $actFee );
	$asTSXLoClobPsv += $psvFee;
	$asTSXLoClobTot += $totFee;
	$asTSXLoPS += $psvFee if $subProd =~ /_PS/;
}
foreach my $subProd ( grep { /V_HI_(DEBT|CLOB)/ } @{ $asFile->keys ( 'PRODUCT' ) } ) {
	my $actFee = $asFile->val ( { PRODUCT => $subProd } , 'ACTIVE_FEE' );
	my $psvFee = $asFile->val ( { PRODUCT => $subProd } , 'PASSIVE_CREDIT' );
	my $totFee = $asFile->val ( { PRODUCT => $subProd } , 'BASIC_FEE' );
	$asTSXVHiClobAct += ( $subProd =~ /_CORR/ ? $totFee : $actFee );
	$asTSXVHiClobPsv += $psvFee;
	$asTSXVHiClobTot += $totFee;
	$asTSXVHiPS += $psvFee if $subProd =~ /_PS/;
}
foreach my $subProd ( grep { /V_LO_(DEBT|CLOB)/ } @{ $asFile->keys ( 'PRODUCT' ) } ) {
	my $actFee = $asFile->val ( { PRODUCT => $subProd } , 'ACTIVE_FEE' );
	my $psvFee = $asFile->val ( { PRODUCT => $subProd } , 'PASSIVE_CREDIT' );
	my $totFee = $asFile->val ( { PRODUCT => $subProd } , 'BASIC_FEE' );
	$asTSXVLoClobAct += ( $subProd =~ /_CORR/ ? $totFee : $actFee );
	$asTSXVLoClobPsv += $psvFee;
	$asTSXVLoClobTot += $totFee;
	$asTSXVLoPS += $psvFee if $subProd =~ /_PS/;
}

# --- FEE SUMM CLOB Passive entries are known to omit Price Setting subprods ---
my $tsxHiClobTot = $tsxHiClobAct + $tsxHiClobPsv + $asTSXHiPS;
my $tsxLoClobTot = $tsxLoClobAct + $tsxLoClobPsv + $asTSXLoPS;
my $tsxvHiClobTot = $tsxvHiClobAct + $tsxvHiClobPsv + $asTSXVHiPS;
my $tsxvLoClobTot = $tsxvLoClobAct + $tsxvLoClobPsv + $asTSXVLoPS;

# FEE SUMM Net Hi CLOB entry is known to omit T_HI_CLOB_ETF_PS, all JITNEY PS subprods,
# and V_HI_DEBT_PS (??)
# -------------------------------------------------------------------------------------
my @hiClobAdjSPs = qw ( T_HI_CLOB_JIT_PS T_HI_CLOB_JIT_INTL_PS T_HI_CLOB_ETF_PS T_HI_CLOB_ETF_JIT_PS 
						V_HI_CLOB_JIT_PS V_HI_DEBT_PS V_HI_DEBT_JIT_PS );
my @loClobAdjSPs = qw ( T_LO_CLOB_JITNEY_T1_PS T_LO_CLOB_JITNEY_T2_PS 
						V_LO_CLOB_JIT_T1_PS V_LO_CLOB_JIT_T2_PS );
						
my ( $asHiClobAdj , $asLoClobAdj );
foreach my $subProd ( @hiClobAdjSPs ) {
	$asHiClobAdj += $asFile->val ( { PRODUCT => $subProd } , 'BASIC_FEE' );
}
foreach my $subProd ( @loClobAdjSPs ) {
	$asLoClobAdj += $asFile->val ( { PRODUCT => $subProd } , 'BASIC_FEE' );
}

if ( 1 ) {
# $hiNet += $asHiClobAdj; 

printf "FS HI TSX  : %.2f,%.2f,%.2f,%.2f\n" , $tsxHiClobAct , $tsxHiClobPsv , $tsxHiClobPsv + $asTSXHiPS , $tsxHiClobTot;
printf "AS HI TSX  : %.2f,%.2f,%.2f\n" , $asTSXHiClobAct , $asTSXHiClobPsv , $asTSXHiClobTot;
printf "FS LO TSX  : %.2f,%.2f,%.2f,%.2f\n" , $tsxLoClobAct , $tsxLoClobPsv , $tsxLoClobPsv + $asTSXLoPS , $tsxLoClobTot;
printf "AS LO TSX  : %.2f,%.2f,%.2f\n" , $asTSXLoClobAct , $asTSXLoClobPsv , $asTSXLoClobTot;
printf "FS HI TSXV : %.2f,%.2f,%.2f,%.2f\n" , $tsxvHiClobAct , $tsxvHiClobPsv , $tsxvHiClobPsv + $asTSXVHiPS , $tsxvHiClobTot;
printf "AS HI TSXV : %.2f,%.2f,%.2f\n" , $asTSXVHiClobAct , $asTSXVHiClobPsv , $asTSXVHiClobTot;
printf "FS LO TSXV : %.2f,%.2f,%.2f,%.2f\n" , $tsxvLoClobAct , $tsxvLoClobPsv , $tsxvLoClobPsv + $asTSXVLoPS , $tsxvLoClobTot;
printf "AS LO TSXV : %.2f,%.2f,%.2f\n" , $asTSXVLoClobAct , $asTSXVLoClobPsv , $asTSXVLoClobTot;

printf "FS/AS HI NET : %.2f,%.2f\n" , $hiNet , $asTSXHiClobTot + $asTSXVHiClobTot;
printf "FS/AS LO NET : %.2f,%.2f\n" , $loNet , $asTSXLoClobTot + $asTSXVLoClobTot;
}

if ( 0 ) {
printf "%.2f" . ",%.2f" x 39 . "\n" , 
		$tsxHiClobAct , $asTSXHiClobAct , $tsxHiClobPsv , $asTSXHiPS , $tsxHiClobPsv + $asTSXHiPS , $asTSXHiClobPsv , $tsxHiClobTot , $asTSXHiClobTot ,
		$tsxvHiClobAct , $asTSXVHiClobAct , $tsxvHiClobPsv , $asTSXVHiPS , $tsxvHiClobPsv + $asTSXVHiPS , $asTSXVHiClobPsv , $tsxvHiClobTot , $asTSXVHiClobTot ,
		$tsxLoClobAct , $asTSXLoClobAct , $tsxLoClobPsv , $asTSXLoPS , $tsxLoClobPsv + $asTSXLoPS , $asTSXLoClobPsv , $tsxLoClobTot , $asTSXLoClobTot ,
		$tsxvLoClobAct , $asTSXVLoClobAct , $tsxvLoClobPsv , $asTSXVLoPS , $tsxvLoClobPsv + $asTSXVLoPS , $asTSXVLoClobPsv , $tsxvLoClobTot , $asTSXVLoClobTot ,
		$hiNet , $asHiClobAdj , $hiNet + $asHiClobAdj , $asTSXHiClobTot + $asTSXVHiClobTot ,
		$loNet , $asLoClobAdj , $loNet + $asLoClobAdj , $asTSXLoClobTot + $asTSXVLoClobTot;
}