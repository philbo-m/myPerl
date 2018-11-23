package TMX;

use strict;
use POSIX qw ( strftime );

use CSV;
use Util;

sub getRootDateDir {
	my ( $rootDir , $yyyymm ) = @_;
	my ( $yyyy , $mm ) = ( $yyyymm =~ /^(\d\d\d\d)(\d\d)$/ );
	
	my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );
	
	my $dateDir = "$rootDir/??-$mmm-$yyyy";
	return ( glob ( $dateDir ) )[ 0 ];
}
	
sub getFeesAndRebates {
	my ( $rootDir , $yyyy , $mm ) = @_;
	my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );
	
	my $fileStr = "$rootDir/??-$mmm-$yyyy/common/pofeereconsum_${yyyy}*.csv";
	my $feeFile =  ( glob ( $fileStr ) )[ 0 ];
	if ( !$feeFile ) {
		die "No TMX fee recon file matching [$fileStr]";
	}

	open FEE , $feeFile or die "Cannot open TMX fee recon file [$feeFile] : $!";
	
	my %feeMap = ();
	
#	Skip down to the section containing trading fee and RT Rebate info.
#	-------------------------------------------------------------------
	while ( 1 ) {
		while ( <FEE> ) {
			last if /(BROKERS WITH RT REBATE|ELP GROUP ID|MSGP PRODUCT DESCRIPTION)/;
		}
		if ( /BROKERS WITH RT REBATE/ ) {
			processFeesAndRebates ( \%feeMap , \*FEE );
		}
		elsif ( /ELP GROUP ID/ ) {
			processELP ( \%feeMap , \*FEE );
		}
		elsif ( /MSGP PRODUCT DESCRIPTION/ ) {
			processProducts ( \%feeMap , \*FEE );
		}
		else {
			last;
		}
	}
		
	close FEE;
	
	return \%feeMap;
}

sub processFeesAndRebates {
	my ( $feeMap , $fh ) = @_;
		
	while ( <$fh> ) {
		chomp;

		my $rec = CSV::parseRec ( $_ );
		my ( $po , $poName , $fee , $rtRebate ) = ( @$rec[ 0 , 1 , 4 , 5 ] );
		return if $po =~ /^\s*$/;
		
		$$feeMap{ "PO" }{ $po }{ "NAME" } = "\"$poName\"";
		$$feeMap{ "PO" }{ $po }{ "FEE" } = $fee;
		$$feeMap{ "PO" }{ $po }{ "RTREBATE" } = $rtRebate;
	}
}

sub processELP {
	my ( $feeMap , $fh ) = @_;
	
	while ( <$fh> ) {
		chomp;
		
		my $rec = CSV::parseRec ( $_ );
		my ( $po , $elpGrpID , $elpDesc , $elpRebate ) = ( @$rec[ 0 , 2 , 3 , 4 ] );
		return if $po =~ /^\s*$/;
			
		push  ( @{ $$feeMap{ "PO" }{ $po }{ "ELPREBATE" } } , [ "$elpGrpID $elpDesc" , $elpRebate ] );
	}
}

sub processProducts {
	my ( $feeMap , $fh ) = @_;

	while ( <$fh> ) {		
		chomp;
		
		my $rec = CSV::parseRec ( $_ );
		my ( $prodID , $prodDesc , $fee ) = ( @$rec[ 0 , 1 , 2 ] );
		last if $prodID =~ /^\s*$/;
		
		$$feeMap{ "PRODUCT" }{ $prodDesc }{ "FEE" } = $fee;
		$$feeMap{ "PRODUCT" }{ $prodDesc }{ "IDX" } = $prodID;
	}
}

sub getVolumes {
	my ( $rootDir , $yyyy , $mm ) = @_;

	my $mmm = uc ( strftime ( "%b" , 0 , 0 , 0 , 1 , $mm - 1 , $yyyy - 1900 ) );
	
	my $fileStr = "$rootDir/??-$mmm-$yyyy/common/tdrsalesum_${yyyy}*.csv";
	my $tdrsFile =  ( glob ( $fileStr ) )[ 0 ];
	if ( !$tdrsFile ) {
		die "No TMX fee recon file matching [$fileStr]";
	}

	open FILE , $tdrsFile or die "Cannot open TMX TdrSaleSum file [$tdrsFile] : $!";
	<FILE>;	# --- skip header ---

	my %volByPO = ();
	while ( <FILE> ) {
		chomp;
		s/"//g;
		my ( $po , $subProd , $qty ) = ( split /,/ )[ 0 , 4 , 5 ];
#		$qty = Util::transformQty ( $subProd , $qty );
		$volByPO{ $po } += $qty;
	}
	close FILE;
	
	return \%volByPO;
}	
	
sub getTdrSalesSumQtys {

	my ( $fileStr ) = @_;
	
	my %qtyMap = ();
		
	my $tdrsFile =  ( glob ( $fileStr ) )[ 0 ];
	if ( !$tdrsFile ) {
		die "No TMX TdrSaleSum file matching [$fileStr]";
	}

	open FILE , $tdrsFile or die "Cannot open TMX TdrSaleSum file [$tdrsFile] : $!";
	<FILE>;	# --- skip header ---
	
	while ( <FILE> ) {
		chomp;
		s/"//g;
		my ( $sym , $subProd , $qty , $fee ) = ( split /,/ )[ 3 , 4 , 5 , 11 ];
		$qty = Util::transformQty ( $subProd , $qty );
		$qtyMap{ $subProd }{ "VOL" } += $qty;
		$qtyMap{ $subProd }{ "FEE" } += $fee;
	}
	close FILE;
	
	return \%qtyMap;
}

1;