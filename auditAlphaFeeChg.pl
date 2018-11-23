#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use Billing::TraderProductDetail;
use Billing::FeeConvAlpha;
use Billing::AlphaSubProdMap;

sub printRec {
	my ( $key , $v1 , $v2 ) = @_;
	if ( $v1 =~ /^[-\d.]*$/ ) {
		$v1 = sprintf ( "%.2f" , $v1 );
	}
	if ( $v2 =~ /^[-\d.]*$/ ) {
		$v2 = sprintf ( "%.2f" , $v2 );
	}
	print "$key,$v1,$v2\n";
}

sub valMatch { 
	my ( $v1 , $v2 ) = @_;

	if ( abs ( $v1 ) < 0.05 || abs ( $v2 ) < 0.05 ) {
		return ( abs ( $v1 - $v2 ) < 0.10 );
	}
	else {
		return ( abs ( ( $v1 - $v2 ) / ( $v1 + $v2 ) ) < 0.005 );
	}
}

sub transformOld {
	my ( $oldFile , $oldFeeMap ) = @_;
	
	foreach my $key ( sort keys %$oldFeeMap ) {
		my $mnemonic = $AlphaSubProdMap::revSubProdMap{ $key };
		next if ( !exists $FeeConvAlpha::feeMap{ 'OLD' }{ $mnemonic } );
		
		my $oldFees = $FeeConvAlpha::feeMap{ 'OLD' }{ $mnemonic };
		my $newFees = $FeeConvAlpha::feeMap{ 'NEW' }{ $mnemonic };
		
		my $actFee = $oldFile->val ( { PRODUCT => $key } , 'ACTIVE_FEE' );
		my $psvCrd = $oldFile->val ( { PRODUCT => $key } , 'PASSIVE_FEE' );
				
		if ( exists $$oldFees{ 'ACT' } ) {
#			print STDERR "[$key] ACT [$$oldFees{ 'ACT' }] -> [$$newFees{ 'ACT' }]\n";
			$actFee *= $$newFees{ 'ACT' } / $$oldFees{ 'ACT' };
		}
		if ( exists $$oldFees{ 'PSV' } ) {
#			print STDERR "[$key] PSV [$$oldFees{ 'PSV' } -> [$$newFees{ 'PSV' }]\n";
			$psvCrd *= $$newFees{ 'PSV' } / $$oldFees{ 'PSV' };
		}
		
#		print STDERR "Converting old [$key] fee from [$$oldFeeMap{ $key }] to [" , $actFee + $psvCrd , "]\n";
		$$oldFeeMap{ $key } = $actFee + $psvCrd;
	}
}

my $oldFile = new TraderProductDetail (
					file	=> $ARGV[ 0 ]
				);
		
my $newFile = new TraderProductDetail (
					file	=> $ARGV[ 1 ]
				);
				
# Compare volume/value totals first.
# ----------------------------------
foreach my $key ( qw ( TOTAL_VOLUME PASSIVE_VOLUME CAPPED_TRADES TOTAL_VALUE PASSIVE_VALUE TOTAL_TRADES PASSIVE_TRADES ) ) {
	my $oldVal = $oldFile->val ( {} , $key );
	my $newVal = $oldFile->val ( {} , $key );
#	print "[$key] [$oldVal] [$newVal]\n";
	if ( !valMatch ( $oldVal , $newVal ) ) {
		print STDERR "TOTAL [$key] MISMATCH : $oldVal , $newVal\n";
	}
}

my ( %oldFeeMap , %newFeeMap );

foreach my $key ( @{ $oldFile->keys ( 'PRODUCT' ) } ) {
	if ( !exists $AlphaSubProdMap::revSubProdMap{ $key } ) {
		print STDERR "ERROR : unknown subproduct [$key] in file [$oldFile->{file}]\n";
		exit 1;
	}
	$oldFeeMap{ $key } = $oldFile->val ( { PRODUCT => $key } , 'NET_FEE' );
#	print "OLD [$key] [$oldFeeMap{ $key }]...\n";
}
foreach my $key ( @{ $newFile->keys ( 'PRODUCT' ) } ) {
	if ( !exists $AlphaSubProdMap::revSubProdMap{ $key } ) {
		print STDERR "ERROR : unknown subproduct [$key] in file [$newFile->{file}]\n";
		exit 1;
	}
	$newFeeMap{ $key } = $newFile->val ( { PRODUCT => $key } , 'NET_FEE' );
#	print "NEW [$key] [$oldFeeMap{ $key }]...\n";
}

# Make straight fee adjustments in old file.
# ------------------------------------------
transformOld ( $oldFile , \%oldFeeMap );

foreach my $key ( sort keys %oldFeeMap ) {
	if ( !exists $newFeeMap{ $key } ) {
		printRec ( $key , $oldFeeMap{ $key } , "N/A" );
		next;
	}
	if ( !valMatch ( $oldFeeMap{ $key } , $newFeeMap{ $key } ) ) {
		printRec ( $key , $oldFeeMap{ $key } , $newFeeMap{ $key } );
	}
	
}

foreach my $key ( sort keys %newFeeMap ) {
	if ( !exists $oldFeeMap{ $key } ) {
		printRec ( $key , "N/A" , $newFeeMap{ $key } );
	}
}
