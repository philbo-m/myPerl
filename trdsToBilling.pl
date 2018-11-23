#!c:/perl/bin/perl

use strict;
use Data::Dumper;

our %bucketFldMap = (
	EXCHANGE_ID			=> {
		EXCHANGE_PARTY_ID	=> {
			2033	=> 'TSX' ,
			2034	=> 'TSXV'
		}
	} ,
	SYMBOL_GROUP		=> 'BILLING_GROUP_ID' ,
	ACTIVE_PASSIVE		=> 'CALC_ORDER_CLASSIFICATION' ,
	TRADING_SESSION		=> 'CALC_SESSION_FLAG' ,
	RT					=> 'RT_FLAG' ,
	EXECUTION_STATE		=> 'EXECUTION_STATE' ,
	UNDISPLAYED			=> 'UNDISPLAYED_FLAG' ,
	ACCOUNT_TYPE		=> 'ORDER_ACCOUNT_TYPE_ID' ,
	O_ACTIVE_PASSIVE	=> \&getOActPsv ,
	O_RT				=> \&getORT ,
	O_UNDISPLAYED		=> 'OPPOSITE_UNDISPLAYED_FLAG' ,
	O_ACCOUNT_TYPE		=> 'OPPOSITE_ORDER_ACCOUNT_TYPE_ID' ,
	O_RT_AUTOFILL		=> 'OPPOSITE_RT_AUTOFILL_TYPE' ,
	SELL_BUY_SAME_BRO	=> \&getBSSamePO ,
	HIGH_LOW			=> \&getHiLo ,
	MOC_FLAG			=> 'MOC_FLAG' ,
	O_MOC_FLAG			=> 'OPPOSITE_MOC_FLAG' ,
	TRADE_CORRECTION	=> 'CALC_TRADE_CORRECTION_FLAG' ,
	JITNEY				=> 'CALC_JITNEY_FLAG' ,
	ICEBERG_HIDDEN		=> \&getIcebergHidden ,
	ICEBERG_DISPLAY		=> 'xxx' ,
	CROSS_TYPE			=> 'CALC_SPECIAL_CROSS_FLAG' ,
	PRIVATE_ORIG_PRIC	=> 'PRIVATE_ORIG_ORDER_PRICE_TYPE' ,
	MGF					=> 'MGF_CANDIDATE' ,
	BOARDLOT_ODDLOT		=> {
		ODDLOT_FLAG			=> {
			'Y'		=> 'O' ,
			'N'		=> 'B'
		}
	} ,
	SETTLEMENT_TERM		=> 'ST_FLAG' ,
	RT_AUTOFILL			=> 'RT_AUTOFILL_TYPE' ,
	INTERLISTED_FLAG	=> 'INTERLISTED_FLAG' ,
	LONG_LIFE_FLAG		=> 'LONG_LIFE_FLAG' ,
	PRODUCT_CODE		=> 'PRODUCT_TYPE_CODE' ,
	TTW_LP				=> 'TTW_LP' ,
	O_TTW_LP			=> 'O_TTW_LP' ,
	SDL_FLAG			=> 'SDL_FLAG' ,
	PRICE_SETTING_FLAG	=> 'PRICE_SETTING_FLAG' ,
	PEG_TYPE			=> 'PEG_TYPE' ,
	TIME_IN_FORCE		=> 'TIME_IN_FORCE' ,
	TRADE_ID			=> 'TRADE_ID' ,
	PRODUCT_ID			=> 'PRODUCT_ID' ,
	PRODUCT_MNEMONIC	=> 'PRODUCT_MNEMONIC' ,
	BROKER_NUMBER		=> 'BROKER_NUMBER' ,
	SYM_TIER			=> \&getTier ,
);

sub getOActPsv {
	my ( $trdFldMap ) = @_;
	
	my $oAdminTag = $$trdFldMap{ OPPOSITE_ADMIN_TAG };
	return ( split ( // , $oAdminTag ) )[ 1 ];
}

sub getHiLo {
	my ( $trdFldMap ) = @_;
	
	my $prc = $$trdFldMap{ TRADE_PRICE_AMOUNT };
	return ( 
		$prc >= 1.0 ? "H" :
		$prc >= 0.10 ? "L2" :
		"L1"
	);
}

sub getORT {
	my ( $trdFldMap ) = @_;
	
	my $oAdminTag = $$trdFldMap{ OPPOSITE_ADMIN_TAG };
	return ( split ( // , $oAdminTag ) )[ 3 ];
}

sub getBSSamePO {
	my ( $trdFldMap ) = @_;
	
	my $po = $$trdFldMap{ BROKER_NUMBER };
	my $oPO = $$trdFldMap{ OPPOSITE_BROKER };
	return ( $po == $oPO ? 'Y' : 'N' );
}

sub isPossIceberg {
	my ( $trdFldMap ) = @_;
	
	my $session = $$trdFldMap{ CALC_SESSION_FLAG };
	my $actPsv = $$trdFldMap{ CALC_ORDER_CLASSIFICATION };
	my $isCorr = $$trdFldMap{ CALC_TRADE_CORRECTION_FLAG };
	my $isMOC = $$trdFldMap{ MOC_FLAG };
	my $isCross = $$trdFldMap{ CALC_SPECIAL_CROSS_FLAG };
	my $isRT = $$trdFldMap{ RT_FLAG };
	my $acctType = $$trdFldMap{ ORDER_ACCOUNT_TYPE_ID };
	
	return ( $session eq 'P' && $actPsv eq 'P' && $isCorr =~ /^ *$/
			&& $isMOC eq 'N' && $isCross eq 'N' && !( $isRT eq 'Y' && $acctType == 631 ) );
}

sub getIcebergHidden {
	my ( $trdFldMap ) = @_;
	
	my $isPossIceberg = isPossIceberg ( $trdFldMap );
	my $undisclVol = $$trdFldMap{ UNDISCL_TRADED_VOL };
	
	return ( $isPossIceberg && $undisclVol > 0 ? "Y" : "N" );
}

# TEMP HACK WHILE WE DON'T HAVE TIER INFO
# ---------------------------------------
sub getTier {
	my ( $trdFldMap ) = @_;
	
	my $sym = $$trdFldMap{ TICKER_SYMBOL };
	my $offset = substr ( $sym , 0 , 1 ) - 'A';
	return ( $offset % 2 ? 'B' : 'A' );
}

# Read the header rec.
# --------------------
my $hdr = <>;
chomp $hdr;
$hdr =~ s/'//g;

my $i = 0;
my %trdFldNameMap = map { $_ => $i++ } split ( /,/ , $hdr );
my %revTrdFldNameMap = map { $trdFldNameMap{ $_ } => $_ } keys %trdFldNameMap;

print join ( "," , sort keys %bucketFldMap ) , "\n";

while ( <> ) {
	chomp; s/'//g;
	my $i = 0;
	my %trdFldMap = map { $revTrdFldNameMap{ $i++ } => $_ } split ( /,/ );
	my @bucketVals = ();
	foreach my $bucketKey ( sort keys %bucketFldMap ) {
		my $trdFld = $bucketFldMap{ $bucketKey };
		my $bucketVal;
		if ( !ref ( $trdFld ) ) {
			$bucketVal = $trdFldMap{ $trdFld };
		}
		elsif ( ref ( $trdFld ) eq 'HASH' ) {
			my $trdFldKey = ( keys %$trdFld )[ 0 ];
			$bucketVal = $$trdFld{ $trdFldKey }{ $trdFldMap{ $trdFldKey } };
		}
		elsif ( ref ( $trdFld ) eq 'CODE' ) {
			$bucketVal = &$trdFld ( \%trdFldMap );
		}
		push @bucketVals , $bucketVal;
	}	
	print join ( "," , @bucketVals ) , "\n";
}		
	
