#!/usr/bin/env perl

use strict;
use Getopt::Long;

my %mscsSubProdMap = (
	A	=> {
		H	=> "T_HI_OL" ,
		L	=> "T_LO_OL" ,
	} ,
	G	=> {
		H	=> {
			Y	=> "T_HI_MGF_INTL" ,
			N	=> "T_HI_MGF" ,
		} ,
		L	=> "T_LO_MGF"
	} ,
	C	=> {
		H	=> "T_HI_MOC_AUTOFILL" ,
		L	=> "T_LO_MOC_AUTOFILL"
	}
);

my %subProdConvMap = (
	T_HI_MGF			=> "T_HI_CLOB" , 
	T_HI_MGF_INTL		=> "T_HI_CLOB_INTL" ,
	T_HI_MOC_AUTOFILL	=> "T_HI_MOC" ,
	T_HI_OL				=> {
								Y	=> "T_HI_CLOB_INTL" ,
								N	=> "T_HI_CLOB"
							} ,
	T_LO_MGF			=> {
								T1	=> "T_LO_CLOB_T1" ,
								T2	=> "T_LO_CLOB_T2"
							} ,
	T_LO_MOC_AUTOFILL	=> "T_LO_MOC" ,
	T_LO_OL				=> {
								T1	=> "T_LO_CLOB_T1" ,
								T2	=> "T_LO_CLOB_T2"
							}
);

my %subProdRateMap = (
	T_HI_MGF			=> 0.0017 ,
	T_HI_MGF_INTL		=> 0.0030 ,
	T_HI_OL				=> 0.0005 ,
	T_HI_MOC_AUTOFILL	=> 0.0005 ,
	T_LO_MGF			=> 0.0004 ,
	T_LO_OL				=> 0.00025 ,
	T_LO_MOC_AUTOFILL	=> 0.00025 ,
	T_HI_CLOB			=> 0.0015 ,
	T_HI_CLOB_INTL		=> 0.0027 ,
	T_HI_MOC			=> 0.0025 ,
	T_LO_CLOB_T1		=> 0.000025 ,
	T_LO_CLOB_T2		=> 0.000075 ,
	T_LO_MOC			=> 0.0002
);

sub getMSCSSubProd {
	my ( $autoType , $price , $intl ) = @_;
	my $priceCat = ( $price >= 1.00 ? "H" : "L" );
	my $subProd = $mscsSubProdMap{ $autoType }{ $priceCat };
	if ( ref $subProd ) {
		$subProd = $$subProd{ $intl };
	}
	return $subProd;
}

sub getConvSubProd {
	my ( $mscsSubProd , $price , $intl ) = @_;
	my $convSubProd = $subProdConvMap{ $mscsSubProd };
	if ( ref $convSubProd ) {
		if ( grep { /^[YN]$/ } keys %$convSubProd ) {
			$convSubProd = $$convSubProd{ $intl };
		}
		else {
			my $priceTier = ( $price >= 0.10 ? "T2" : "T1" );
			$convSubProd = $$convSubProd{ $priceTier };
		}
	}
	return $convSubProd;
}
	
my $tdrsFile;

GetOptions ( 
	't=s'	=> \$tdrsFile
) or exit 1;

exit 1 if !$tdrsFile;

my %intlSymMap = ();

open ( FILE , $tdrsFile ) or die "Cannot open TDRSALESUM file [$tdrsFile] : $!";
while ( <FILE> ) {
	s/"//g;
	my ( $sym , $subProd ) = ( split /,/ )[ 3 , 4 ];
	if ( $subProd =~ /_INTL/ ) {
		$intlSymMap{ $sym } = 1;
	}
}
close FILE;

my %feeMap = ();

# Input to this script is the output of secRTTrds.pl:
# DATE,TIME,PO,TRDRID,RT_PO,RT_TRDRID,RT_AUTO,SYM,VOL,PRICE,HI_LO
# ---------------------------------------------------------------
print "PO,TRDRID,SYM,SUBPROD,VOL,RATE,FEE,ORIG_SUBPROD,ORIG_RATE,ORIG_FEE\n";

while ( <> ) {
	chomp;
	my ( $po , $trdrID , $autoType , $sym , $vol , $price ) = ( split /,/ )[ 2 , 3 , 6 , 7 , 8 , 9 ];
	next if $po !~ /^\d+$/;
	$po = sprintf ( "%03d" , $po );

	my $intl = ( exists $intlSymMap{ $sym } ? "Y" : "N" );
	my $mscsSubProd = getMSCSSubProd ( $autoType , $price , $intl );
	my $origSubProd = getConvSubProd ( $mscsSubProd , $price , $intl );
	
	my $key = "$po,$trdrID,$sym";
	$feeMap{ $key }{ $mscsSubProd }{ $origSubProd } += $vol;
}

foreach my $key ( sort keys %feeMap ) {
	foreach my $mscsSubProd ( sort keys %{ $feeMap{ $key } } ) {
		my $rate = $subProdRateMap{ $mscsSubProd };
		foreach my $origSubProd ( sort keys %{ $feeMap{ $key }{ $mscsSubProd } } ) {
			my $vol = $feeMap{ $key }{ $mscsSubProd }{ $origSubProd };
			my $origRate = $subProdRateMap{ $origSubProd };
			printf "%s,%s,%d,%.6f,%.2f,%s,%.6f,%.2f\n" ,
				$key , 
				$mscsSubProd , $vol , $rate , $vol * $rate ,
				$origSubProd , $origRate , $vol * $origRate
		}
	}
}
