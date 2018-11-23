#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use Activ::ActivFile;

my @flds;
my $tabular = 1;

GetOptions ( 
	'f=s'	=> \@flds ,
) or die;
$tabular = 0 if !@flds;

if ( @flds ) {
	@flds = map { split /,/ } join ( "," , @flds );
}

# Print header, if in tabular mode.
# ---------------------------------
if ( $tabular ) {
	print join ( "," , @flds ) , "\n";
}

my $activFile = new Activ::ActivFile ( File => $ARGV[ 0 ] , maxBuf => 10000 );
while ( my $activMsg = $activFile->next () ) {
	
	print $activMsg->showMsg ( \@flds ) , ( @flds ? "\n" : "\n\n" );
}
