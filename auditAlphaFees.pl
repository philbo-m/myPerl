#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use Data::Dumper;

use File::Basename;
use lib dirname $0;

use Billing::TraderDetail;
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

print STDERR "Reading files...\n";
my %rptFiles = (
	TD	=> new TraderDetail ( file => [ glob ( "TRADER_DETAIL_*CLOB*" ) ] , 
								keyFlds => [ 'TRADER_ID' , 'SYMBOL' , 'PRODUCT' ] ) ,
	TPD	=> new TraderProductDetail ( file => glob ( "TRADER_PRODUCT_DETAIL*" ) )
);

# Ensure fee distribution is the same among Subproducts.
# ------------------------------------------------------
my %subProdFeeMap;

foreach ( keys %rptFiles ) {
	my $file = $rptFiles{ $_ };
	foreach my $subProd ( @{ $file->keys ( 'PRODUCT' ) } ) {
		foreach my $feeKey ( 'ACTIVE_FEE' , 'PASSIVE_FEE' , 'NET_FEE' ) {
			$subProdFeeMap{ $_ }{ $subProd }{ $feeKey } = $file->val ( { PRODUCT => $subProd } , $feeKey );
		}
	}
}

foreach my $subProd ( sort keys %{ $subProdFeeMap{ "TD" } } ) {
	foreach my $feeKey ( 'ACTIVE_FEE' , 'PASSIVE_FEE' , 'NET_FEE' ) {
		my $tdVal = $subProdFeeMap{ "TD" }{ $subProd }{ $feeKey };
		if ( !exists $subProdFeeMap{ "TPD" }{ $subProd } ) {
			printf "$subProd,$feeKey,%.2f,N/A,NOT IN TPD\n" , $tdVal;
		}
		else {
			my $tpdVal = $subProdFeeMap{ "TPD" }{ $subProd }{ $feeKey };
			my $status = ( valMatch ( $tdVal , $tpdVal ) ? "OK" : "DIFF" );
			printf "$subProd,$feeKey,%.2f,%.2f,$status\n" , $tdVal ,
					$subProdFeeMap{ "TPD" }{ $subProd }{ $feeKey };
		}
	}
}
foreach my $subProd ( sort keys %{ $subProdFeeMap{ "TPD" } } ) {
	next if exists $subProdFeeMap{ "TD" }{ $subProd };
	foreach my $feeKey ( 'ACTIVE_FEE' , 'PASSIVE_FEE' , 'NET_FEE' ) {
		my $tpdVal = $subProdFeeMap{ "TPD" }{ $subProd }{ $feeKey };
		printf "$subProd,$feeKey,N/A,%.2f,NOT IN TD\n" , $tpdVal;
	}
}

foreach my $volKey ( 'TOTAL_VOLUME' , 'PASSIVE_VOLUME' , 'VOL <= CAP' , 'CAPPED_TRADES' , 'TOTAL_VALUE' , 
					'PASSIVE_VALUE' , 'TOTAL_TRADES' , 'PASSIVE_TRADES' ) {
	my $tdVal = $rptFiles{ "TD" }->val ( {} , $volKey );
	my $tpdVal = $rptFiles{ "TPD" }->val ( {} , $volKey );
	my $status = ( valMatch ( $tdVal , $tpdVal ) ? "OK" : "DIFF" );
	printf "$volKey,%.2f,%.2f,$status\n" , $tdVal , $tpdVal;
}

	