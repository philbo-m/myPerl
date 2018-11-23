#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use CSV;

my ( $unFlatten , $quoteAllFlds , $singleLineMode );

GetOptions ( 
	'u'		=> \$unFlatten ,
	'a'		=> \$quoteAllFlds ,
	's'		=> \$singleLineMode
) or die;

binmode STDIN;

my $recs;
if ( !$singleLineMode ) {
	my $save = $/;
	$/ = undef;
	$recs = <>;
	$/ = $save;
}

if ( !$unFlatten ) {
	if ( $singleLineMode ) {
		while ( <> ) {
			my $outRec = CSV::flattenRec ( CSV::parseRec ( $_ ) );
			print join ( "," , @$outRec ) , "\n";
		}	
	}
	else {
		my $outRecs = CSV::flattenRecs ( CSV::parseRecs ( $recs ) );
		print join ( "\n" , map { join "," , @$_ } @$outRecs ) , "\n";
	}
}

else {
	binmode STDOUT;
	if ( $singleLineMode ) {
		while ( <> ) {
			my $outRec = CSV::unflattenRec ( CSV::parseRec ( $_ ) , $quoteAllFlds );
			print join ( "," , @$outRec ) , "\015\012";
		}
	}
	else {
		my $outRecs = CSV::unflattenRecs ( CSV::parseRecs ( $recs ) , $quoteAllFlds );
		print join ( "\015\012" , map { join "," , @$_ } @$outRecs ) , "\015\012";
	}
}	