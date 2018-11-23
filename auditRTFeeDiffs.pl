#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use CSV;
use Billing::FeeConv;

my $DEBUG = 0;

sub dbg {
	if ( $DEBUG ) {
		print STDERR join ( " " , @_ ) , "\n";
	}
}

sub abs {
	my ( $v ) = @_;
	return ( $v < 0 ? $v * -1 : $v );
}

sub isBonusEligible {
	my ( $subProd ) = @_;
	return ( $subProd !~ /_(LO_|ETF|OL|MOO|MOC|PART)/ );
}

sub isInterlisted {
	my ( $subProd ) = @_;
	return ( $subProd =~ /_INTL/ );
}

sub isETF {
	my ( $subProd ) = @_;
	return ( $subProd = /_ETF/ );
}

sub isRT {
	my ( $subProd ) = @_;
	return ( $subProd = /_RT/ );
}

my %intlBySym = ();
my %rtRoleBySymPO = ();

GetOptions ( 
	'd'		=> \$DEBUG ,
) or die;

# Use the RTTRADERBONUS file to get RTs' roles on their symbols.
# --------------------------------------------------------------
open ( RTB , $ARGV[ 0 ] ) or die ( "Cannot open Bonus Tier file [$ARGV[ 0 ]] : $!" );

<RTB>;	# --- skip header ---
while ( <RTB> ) {
	chomp ; s/"//g;
	my ( $po , $sym , $primSec ) = ( split /,/ )[ 0 , 1 , 5 ];
	
	$rtRoleBySymPO{ $sym }{ $po } = $primSec;
}
close RTB;

# Use the RTTRADERSYMCREDIT file to augment the POs' roles on the symbols.
# (Some RTs won't show up in RTTTRADERBONUS, if there are no bonus-eligible
# subproducts.)
# -------------------------------------------------------------------------
open ( RTS , $ARGV[ 1 ] ) or die ( "Cannot open Sym Credit file [$ARGV[ 1 ]] : $!" );

<RTS>;	# --- skip header ---
while ( <RTS> ) {
	chomp ; s/"//g;
	my $rec = CSV::flattenRec ( CSV::parseRec ( $_ ) );

	my ( $po , $primSec , $sym ) = ( @$rec )[ 0 , 4 , 5 ];
	
	$rtRoleBySymPO{ $sym }{ $po } = $primSec;
}
close RTS;

# Grab the subproduct collapse maps.
# ----------------------------------
my %revSecCollapseMap = ();
foreach my $baseSubProd ( keys %{ $FeeConv::proCollapseMap{ NEW } } ) {
	foreach my $subProd ( @{ $FeeConv::proCollapseMap{ NEW }{ $baseSubProd } } ) {
		$revSecCollapseMap{ $subProd } = $baseSubProd;
	}
}
my %revMGFPartCollapseMap = ();
foreach my $baseSubProd ( keys %{ $FeeConv::collapseMap{ NEW } } ) {
	foreach my $subProd ( @{ $FeeConv::collapseMap{ NEW }{ $baseSubProd } } ) {
		$revMGFPartCollapseMap{ $subProd } = $baseSubProd;
	}
}

# Get interlisteds from the TDRSALESUM file.
# ------------------------------------------
open ( TDRS , $ARGV[ 2 ] ) or die ( "Cannot open Tdrsalesum file [$ARGV[ 2 ]] : $!" );

<TDRS>;	# --- skip header ---
while ( <TDRS> ) {
	chomp ; s/"//g;
	my ( $sym , $subProd ) = ( split /,/ )[ 3 , 4 ];
	if ( isInterlisted ( $subProd ) ) {
		$intlBySym{ $sym } = 1;
	}
}
close TDRS;

# Get trade quantities + fees from the TDRSALESUM file.
# -----------------------------------------------------
open ( TDRS , $ARGV[ 2 ] ) or die ( "Cannot open Tdrsalesum file [$ARGV[ 2 ]] : $!" );

$_ = <TDRS>;	# --- skip header ---
print;

while ( <TDRS> ) {
	chomp ; s/"//g;
	my ( $po , $trdrID , $mkt , $sym , $subProd , $vol , $val , $trds , $actVol , $psvVol , $baseFee , $netFee ) = split /,/;
	if ( !isRT ( $subProd ) ) {
		print "$_\n";
		next;
	}
	my $origSubProd = $subProd;
	my $rtRole = $rtRoleBySymPO{ $sym }{ $po };

	my $tgtSubProd;

#	Collapse new RT participation/MGF subproducts.
#	----------------------------------------------
	if ( exists $revMGFPartCollapseMap{ $subProd } ) {
		$tgtSubProd = $revMGFPartCollapseMap{ $subProd };
		dbg ( "[$sym] RT [$po] [$trdrID] [$subProd] converting to [$tgtSubProd]" );
		
		$subProd = $tgtSubProd;
	}
		
# 	Collapse secondary RT subproducts.
#	----------------------------------
	if ( $rtRole eq 'S' && exists $revSecCollapseMap{ $subProd } ) {
		$tgtSubProd = $revSecCollapseMap{ $subProd };
		dbg ( "[$sym] SEC [$po] [$trdrID] [$subProd] converting to [$tgtSubProd]" );
		
		$subProd = $tgtSubProd;
	}

#	Some secondary RT subproducts collapse to either T1 or T2 low subprods.
#	The collapse map defaults to T1; change it here to T2 if necessary.
#	-----------------------------------------------------------------------	
	if ( $tgtSubProd && $tgtSubProd =~ /_T1/ ) {
		my $prc = $val / $vol;
		if ( $prc > 0.10 ) {
			$tgtSubProd =~ s/_T1/_T2/;
			$subProd = $tgtSubProd;
		}
	}
	
#	Some secondary RT subproducts collapse to either interlisted or non-interlisted
#	HI CLOB.  The collapse map defaults to non-interlisted; change it here if necessary.
#	------------------------------------------------------------------------------------
	if ( $subProd eq 'T_HI_CLOB' && $intlBySym{ $sym } ) {
		$tgtSubProd = 'T_HI_CLOB_INTL';
		$subProd = $tgtSubProd;
	}
	
# 	Proceed if we did collapse this subproduct, or if its rate is changing.
#	-----------------------------------------------------------------------
	if ( $tgtSubProd || exists $FeeConv::rateMap{ OLD }{ $subProd } ) {
	
		my $tgtActRate = $FeeConv::rateMap{ NEW }{ $subProd }{ ACT };
		my $tgtPsvRate = $FeeConv::rateMap{ NEW }{ $subProd }{ PSV };
		if ( exists $FeeConv::rateMap{ OLD }{ $subProd } ) {
			dbg ( "...OLD rates for [$po] [$trdrID] [$sym] [$subProd]..." );
			$tgtActRate = $FeeConv::rateMap{ OLD }{ $subProd }{ ACT };
			$tgtPsvRate = $FeeConv::rateMap{ OLD }{ $subProd }{ PSV };
		}
		
#		--- Patch for MOC and MOO, whose active/passive volumes are zero ---
		if ( $origSubProd =~ /_MO[CO]/ ) {
			$actVol = $vol;
		}

		my $tgtFee = $tgtActRate * $actVol + $tgtPsvRate * $psvVol;
		dbg ( "MAP,$sym,$po,$trdrID,$rtRole,$origSubProd,$actVol,$psvVol,$baseFee,$subProd,$tgtFee" );
		$baseFee = $tgtFee;
		$netFee = $baseFee;
	}
	
	printf "$po,$trdrID,$mkt,$sym,$subProd,$vol,$val,$trds,$actVol,$psvVol,%.2f,%.2f\n" , $baseFee , $netFee;
}
close TDRS;