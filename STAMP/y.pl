#!c:/perl/bin/perl

use strict;

use STAMP::STAMPMsg;
# use STAMP::STAMPMsg;

use Data::Dumper;


# my @flds = qw ( 5 6 56 5 6 56 );
my @flds = qw ( BusinessAction BusinessClass );
my %setFlds = (
		BusinessClass	=> "123" , 
		DEF	=> "456"
	);
	
# my $fld = 5;

while ( <> ) {

	print STDERR "$....\n" if !( $. % 10000 );
	
	my $msg = STAMP::STAMPMsg::newSTAMPMsg ( $_ );
#	my $msg = new STAMP::STAMPMsg ( Rec => $_ );
	next if !$msg;

	foreach my $f ( @flds ) {
		my $val = $msg->getAttr ( $f );
#		print "[$f] [$val]\n";
	}
	
	foreach my $f ( keys %setFlds ) {
		my $v1 = $msg->setAttr ( $f , $setFlds{ $f } );
		my $v2 = $msg->getAttr ( $f );
#		print "[$f] [$v1] [$v2]\n";
	}
	
	next;
	
#	print;
	my $pos = 0;
	while ( $pos >= 0 ) {
		my $prevPos = $pos;
		$pos = index ( $_ , "\036" , $pos + 1 );
		last if $pos < 0;
		my $eqPos = index ( $_ , "=" , $prevPos + 1 );
		my $fld = substr ( $_ , $prevPos + 1 , $eqPos - $prevPos - 1 );
		my $val = substr ( $_ , $eqPos + 1 , $pos - $eqPos - 1 );
#		print "[$fld]=[$val]\n";
#		print "[$pos]...\n";
	}
#	print "[$. $v]\n";
#	print Dumper ( $fm ) , "\n";
}