#!c:/perl/bin/perl

use strict; 

my ( $nfile , $ofile ) = @ARGV;

my %nAcctMap = ();
my %oPosByAcct = ();
my %oEqPosByAcct = ();

open ( NPOS , $nfile ) or die ( "Cannot open new position file \"$nfile\" : $!" ); 
while ( <NPOS> ) {
    chomp;  
    my $acct = ( split /,/ )[ 1 ]; 
    $nAcctMap{ $acct } = 1;  
}
close NPOS;

open ( OPOS , $ofile ) or die ( "Cannot open prev. position file \"$ofile\" : $!" ); 
while ( <OPOS> ) {
    chomp;  
    my ( $acct , $sym , $curr , $lpos , $spos ) = ( split /,/ )[ 1 , 2 , 3 , 7 , 8 ];
	my $npos = abs ( $lpos - $spos );
    $oPosByAcct{ $acct }{ "LONG" } += $lpos;
    $oPosByAcct{ $acct }{ "SHORT" } += $spos;
	if ( $curr eq 'CAD' && ( length ( $sym ) <= 4 || $sym =~ /\./ ) ) {
		$oEqPosByAcct{ $acct }{ "LONG" } += $lpos;
		$oEqPosByAcct{ $acct }{ "SHORT" } += $spos;
	}
}
close OPOS;

foreach my $acct ( sort keys %oPosByAcct ) {
	if ( !exists $nAcctMap{ $acct } ) {
		printf "$acct,%.2f,%.2f,%.2f,%.2f\n" ,
					$oPosByAcct{ $acct }{ "LONG" } , $oPosByAcct{ $acct }{ "SHORT" } ,
					$oEqPosByAcct{ $acct }{ "LONG" } , $oEqPosByAcct{ $acct }{ "SHORT" };
	}
}