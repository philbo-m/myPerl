#!/usr/bin/env perl

use strict;
use Getopt::Long;

use CSVFile;
use Util;

sub interpolateFlds {
	my ( $flds ) = @_;
	my @fldList = ();
	foreach my $fld ( split ( /,/ , $flds ) ) {
		if ( $fld =~ /^(\d+)-(\d+)$/ ) {
			push @fldList , ( $1 .. $2 );
		}
		else {
			push @fldList , $fld;
		}
	}
	return \@fldList;
}

print STDERR "[" , join "] [" , @ARGV , "]\n";

my ( $keyFlds , $ignoreFlds , $ignoreHdr , $reverseOther , $tabular );
GetOptions ( 
	'k=s'	=> \$keyFlds , 
	"i=s"	=> \$ignoreFlds ,
	"h"		=> \$ignoreHdr ,
	"r"		=> \$reverseOther ,
	"t"		=> \$tabular
) or die;

# exit 1 if !$keyFlds;
exit 1 if scalar ( @ARGV ) != 2;

my $keyFldArr = interpolateFlds ( $keyFlds );
my $ignoreFldArr = interpolateFlds ( $ignoreFlds );

print STDERR "KEY FLDS [" , join ( "] [" , @$keyFldArr ) , "]\n";
print STDERR "IGNORE FLDS [" , join ( "] [" , @$ignoreFldArr ) , "]\n";

my $file1 = new CSVFile ( keyFlds => $keyFldArr , ignoreFlds => $ignoreFldArr , useHdr => !$ignoreHdr );
$file1->parse ( $ARGV[ 0 ] );

my $file2 = new CSVFile ( keyFlds => $keyFldArr , ignoreFlds => $ignoreFldArr , useHdr => !$ignoreHdr );
$file2->parse ( $ARGV[ 1 ] );

$file1->cmp ( $file2 , { Tabular => $tabular , ReverseOther => $reverseOther } );
