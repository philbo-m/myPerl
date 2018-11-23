#!c:/perl/bin/perl

use strict;
use Getopt::Long;

my $cs;

GetOptions ( 
	'c'		=> \$cs
) or die;

my %csMap = (
	"CS"		=> "Credit Suisse" ,
	"GS"		=> "Goldman Sachs" ,
	"ITG"		=> "ITG" ,
	"MACQUARIE"	=> "ITG" ,
	"MAPLE"		=> "ITG" ,
	"MORG"		=> "Morgan Stanley" ,
	"TMX"		=> "TMX" ,
	"UBS"		=> "UBS"
);
my $defaultCS = "CS";

my %pluginMap = ();
my $isActive;


while ( <> ) {
	chomp;
	
	if ( /^--Inactive Plugins--$/ ) {
		$isActive = 0;
	}
	elsif ( /^--Active Plugins--$/ ) {
		$isActive = 1;
	}
	
	next if not /^\S+$/;
	
	my $PO;
	if ( $cs ) {
		foreach my $sessPO ( keys %csMap ) {
#			print "[$_] [$sessPO]...\n";
			if ( $_ =~ m/^I_${sessPO}/ ) {
				$PO = $csMap{ $sessPO };
				last;
			}
		}
		if ( !$PO ) {
			$PO = $csMap{ $defaultCS };
		}
	}
	else {
		$PO = "ALL";
	}

#	print "[$PO] [$isActive] [$_]\n";
	$pluginMap{ $PO }{ $isActive }{ $_ } = 1;
}

foreach my $PO ( keys %pluginMap ) {
	foreach my $activePlugin ( keys %{ $pluginMap{ $PO }{ 1 } } ) {
		if ( exists $pluginMap{ $PO }{ 0 }{ $activePlugin } ) {
			print "Plugin [$activePlugin] both inactive and active\n";
			delete $pluginMap{ $PO }{ 0 }{ $activePlugin };
		}
	}
	
	print "$PO : Active Plugins :\n" , join ( "\n" , sort keys %{ $pluginMap{ $PO }{ 1 } } ) , "\n";
	print "$PO : Inactive Plugins :\n" , join ( "\n" , sort keys %{ $pluginMap{ $PO }{ 0 } } ) , "\n";
	print "$PO : Active Plugin Total : " , scalar keys %{ $pluginMap{ $PO }{ 1 } } , "\n";
	print "$PO : Inactive Plugin Total : " , scalar keys %{ $pluginMap{ $PO }{ 0 } } , "\n";
}