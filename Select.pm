package Select;

use Data::Dumper;

use CSV;
use Util;

sub getRootDateDir {
	my ( $rootDir , $yyyymm ) = @_;
	my ( $yyyy , $mm ) = ( $yyyymm =~ /^(\d\d\d\d)(\d\d)$/ );
	
	my $dateDir = "$rootDir/TMXSelect/$yyyy-$mm";
	return ( glob ( $dateDir ) )[ 0 ];
}

sub getVolsAndFees {
	my ( $rootDir , $yyyy , $mm , $byTrdID ) = @_;
	$mm = sprintf ( "%02d" , $mm );
	
	my %feeMap = ();
	
	my $trdFile =  ( glob ( "$rootDir/$yyyy-$mm/common/DETAILED_${yyyy}${mm}??.csv" ) )[ 0 ];
	if ( !$trdFile ) {
		warn "Cannot find [DETAILED] CSV in $rootDir/$yyyy-$mm/common";
		return \%feeMap;
	}
	
	open TRD , $trdFile or die "Cannot open $rootFile CSV in $rootDir : $!";
	<TRD>;

#	Note - this is the trade detail file so both sides of each trade will show up 
#	--> overall trade volumes are double-counted.
#	-----------------------------------------------------------------------------
	my $x = 0;
	while ( <TRD> ) {
	
		# --- PO, TraderID, AcctType, Mkt, Symbol, SubProduct, Volume, Value, No Trade Legs, Active Vol, Passive Vol, Anon Vol, Fee ---
		chomp;
		s/"//g;
		my ( $po , $trdID , $sym , $subProduct , $qty , $fee ) = ( split /,/ )[ 0 , 1 , 4 , 5 , 6 , 12 ];
				
		$qty = Util::transformQty ( $sym , $qty );
	
		if ( $byTrdID ) {
			$feeMap{ $po }{ $trdID }{ $subProduct }{ "VOL" } += $qty;
			$feeMap{ $po }{ $trdID }{ $subProduct }{ "FEE" } += $fee;
		}
		else {
			$feeMap{ $po }{ $subProduct }{ "VOL" } += $qty;
			$feeMap{ $po }{ $subProduct }{ "FEE" } += $fee;
		}
		$x += $qty;
	}
	my $y = 0;
	foreach my $po ( keys %feeMap ) {
		foreach my $subProd ( keys %{ $feeMap{ $po } } ) {
			$y += $feeMap{ $po }{ $subProd }{ "VOL" };
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
		warn "Cannot find [POFEERECONSUM] CSV in $rootDir/$yyyy-$mm/common";
		return \%feeMap;
	}
		
	open FEE , $feeFile or die "Cannot open $feeFile : $!";
	<FEE>;
	
#	By PO.
# 	------
	my $recs;
	while ( <FEE> ) {
		last if /^,/;
		$recs .= $_;
	}
	
	$recs = CSV::parseRecs ( $recs );
	foreach my $rec ( @$recs ) {
		my ( $po , $fee ) = @$rec[ 0 , 4 ];
		$feeMap{ "PO" }{ $po } = $fee;
	}

	while ( <FEE> ) {
		last if /Product Description/i;
	}
	
#	By Product.
# 	-----------
	my $prodIdx = 0;	# --- so we can preserve ordering ---
	$recs = '';
	while ( <FEE> ) {
		$recs .= $_;
	}
	
	$recs = CSV::parseRecs ( $recs );
	foreach my $rec ( @$recs ) {
		my ( $product , $fee ) = @$rec[ 0 , 1 ];
		$feeMap{ "PRODUCT" }{ $product }{ "FEE" } = $fee;
		$feeMap{ "PRODUCT" }{ $product }{ "IDX" } = $prodIdx++;
	}
	close FEE;
	
	return \%feeMap;
}

sub getDetailSumQtys {

	my ( $fileStr ) = @_;
	
	my %qtyMap = ();
		
	my $detailFile =  ( glob ( $fileStr ) )[ 0 ];
	if ( !$detailFile ) {
		warn "No TMXSelect detail file matching [$fileStr]";
		return \%qtyMap;
	}

	open FILE , $detailFile or die "Cannot open TMXSelect detail file [$detailFile] : $!";
	<FILE>;	# --- skip header ---
	
	while ( <FILE> ) {
		chomp;
		s/"//g;
		my ( $subProd , $qty , $fee ) = ( split /,/ )[ 5 , 6 , 12 ];
		$qtyMap{ $subProd }{ "VOL" } += $qty;
		$qtyMap{ $subProd }{ "FEE" } += $fee;
	}
	close FILE;
	
	return \%qtyMap;
}

1;