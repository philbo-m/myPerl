package Alpha;

use CSV;
use Util;

sub getRootDateDir {
	my ( $rootDir , $yyyymm ) = @_;
	my ( $yyyy , $mm ) = ( $yyyymm =~ /^(\d\d\d\d)(\d\d)$/ );
	
	my $dateDir = "$rootDir/Alpha/$yyyy-$mm";
	return ( glob ( $dateDir ) )[ 0 ];
}


sub getVolsAndFees {
	my ( $rootDir , $yyyy , $mm , $byTrdID ) = @_;
	$mm = sprintf ( "%02d" , $mm );
	
	my %feeMap = ();
	
	foreach my $rootFile ( qw ( TDRSALESUM DARK_TDRSALESUM ) ) {

		my $trdFile =  ( glob ( "$rootDir/$yyyy-$mm/common/${rootFile}_${yyyy}${mm}??.csv" ) )[ 0 ];
		if ( !$trdFile ) {
			warn "Cannot find [$rootFile] CSV in $rootDir/$yyyy-$mm/common";
			next;
		}
		
		open TRD , $trdFile or die "Cannot open $rootFile CSV in $rootDir : $!";		
		local $/;
		my $fileContent = <TRD>;
		close TRD;
		
		my $recs = CSV::parseRecs ( $fileContent );
		shift @$recs;	# --- strip the header ---
		
		foreach my $rec ( @$recs ) {
			
			# --- PO , TraderID , Mkt , Symbol , SubProduct , Volume , Value, No Trade Legs, Active Vol, Passive Vol, Fee ---
			my ( $po , $trdID , $sym , $subProduct , $qty , $fee ) =  @$rec[ 0 , 1 , 3 , 4 , 5 , 10 ];
			$subProduct = "A_$subProduct" if $subProduct !~ /^A_/;
					
			$qty = Util::transformQty ( $sym , $qty );
		
#			Special case - avoid double counting AOD Rebate..
#			-------------------------------------------------
			$qty = 0 if $subProduct eq 'A_V_AOD_REBATE';
			
			if ( $byTrdID ) {
				$feeMap{ $po }{ $trdID }{ $subProduct }{ "VOL" } += $qty;
				$feeMap{ $po }{ $trdID }{ $subProduct }{ "FEE" } += $fee;
			}
			else {
				$feeMap{ $po }{ $subProduct }{ "VOL" } += $qty;
				$feeMap{ $po }{ $subProduct }{ "FEE" } += $fee;
			}
		}
	}
	
	return \%feeMap;
}

sub getFeeSumm {
	my ( $rootDir , $yyyy , $mm , $byTrdID ) = @_;
	$mm = sprintf ( "%02d" , $mm );

	my %feeMap = ();
	
	my $feeFile =  ( glob ( "$rootDir/$yyyy-$mm/common/POFEERECONSUM_${yyyy}${mm}??.csv" ) )[ 0 ];
	if ( !$feeFile ) {
		die "Cannot find [POFEERECONSUM] CSV in $rootDir/$yyyy-$mm/common";
	}
		
	open FEE , $feeFile or die "Cannot open $feeFile : $!";
	<FEE>;
	
	my $fileContent;
	
#	By PO.
# 	------
	while ( <FEE> ) {
		last if /^,/;	
		$fileContent .= $_;
	}
	
	my $recs = CSV::parseRecs ( $fileContent );
	foreach my $rec ( @$recs ) {
		my ( $po , $poName , $fee ) = @$rec[ 0 , 1 , 4 ];
		$feeMap{ "PO" }{ $po } = $fee;
	}

	while ( <FEE> ) {
		last if /Product Description/i;
	}
	
	$fileContent = "";
	
#	By Product.
# 	-----------
	while ( <FEE> ) {
		$fileContent .= $_;
		my ( $product , $fee ) = /^"(.*?)",([^,]+)/;
		$feeMap{ "PRODUCT" }{ $product }{ "FEE" } = $fee;
		$feeMap{ "PRODUCT" }{ $product }{ "IDX" } = $prodIdx++;
	}
	close FEE;

	$recs = CSV::parseRecs ( $fileContent );
	my $prodIdx = 0;	# --- so we can preserve ordering ---
	foreach my $rec ( @$recs ) {
		my ( $product , $fee ) = @$rec[ 0 , 1 ];
		$feeMap{ "PRODUCT" }{ $product }{ "FEE" } = $fee;
		$feeMap{ "PRODUCT" }{ $product }{ "IDX" } = $prodIdx++;
	}
	
	return \%feeMap;
}

sub getTdrSalesSumQtys {

	my ( $fileStr , $darkFileStr ) = @_;
	
	my %qtyMap = ();
		
	my $tdrsFile =  ( glob ( $fileStr ) )[ 0 ];
	if ( !$tdrsFile ) {
		die "No Alpha TdrSaleSum file matching [$fileStr]";
	}

	foreach ( $fileStr , $darkFileStr ) {
	
		next if !$_;
		
		if ( !open FILE , $_ ) {
			warn "Cannot open Alpha TdrSaleSum file [$_] : $!";
			next;
		}
		
		<FILE>;	# --- skip header ---
		
		while ( <FILE> ) {
			chomp;
			s/"//g;
			my ( $sym , $subProd , $qty , $fee ) = ( split /,/ )[ 3 , 4 , 5 , 10 ];
			$qty = Util::transformQty ( $subProd , $qty );
			$qtyMap{ $subProd }{ "VOL" } += $qty;
			$qtyMap{ $subProd }{ "FEE" } += $fee;
		}
		close FILE;
	}
	
	return \%qtyMap;
}

1;