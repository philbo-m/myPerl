#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use FIXMsg;

sub mkOrderChain {
	my ( $clOrdID , $clOrdIDsByOrig , $msgTypeByClOrdID ) = @_;
	
	my $chain = $clOrdID;
	while ( $clOrdID ) {
		my $newClOrdIDs = $$clOrdIDsByOrig{ $clOrdID };
		if ( $newClOrdIDs ) {
			if ( scalar @$newClOrdIDs == 1 ) {
#				print STDERR "[$clOrdID] subId [$$newClOrdIDs[ 0 ]]\n";
				$clOrdID = $$newClOrdIDs[ 0 ];
				$chain .= "," . $clOrdID;
			}
			else {
#				print STDERR "[$clOrdID] subChain [" , join ( "," , @$newClOrdIDs ) , "]\n";
				my @subChains = ();
				foreach my $newClOrdID ( @$newClOrdIDs ) {
					push @subChains , mkOrderChain ( $newClOrdID , $clOrdIDsByOrig , $msgTypeByClOrdID );
				}
				$chain .= "," . join ( "|" , @subChains );
				$clOrdID = undef;
			}
		}
		else {
			$clOrdID = undef;
		}
	}
	return $chain;
}

my $delim = "";

GetOptions ( 
	'd=s'	=> \$delim ,
) or die;

my @filters = qw ( 35=D|F|G );
@filters = map { 
				my ( $key , $vals ) = split /=/;
				$vals =~ s/\*/.*?/g;
				"\(^|$delim\)$key=\($vals\)\($delim|\$\)";
			} @filters;
			
my %showTags = map { $_ => 1 } qw ( 1 35 11 41 );

my %msgTypeMap = (
	D	=> 'N' ,
	F	=> 'X' ,
	G	=> 'C'
);

my %clOrdIDsByOrig = ();
my %clOrdIDsByMsgType = ();
my %msgTypeByClOrdID = ();

local $| = 1;

while ( <> ) {
	chomp;
	next if /^\s*$/;
	
	my $matchFilter = 1;
	foreach my $filter ( @filters ) {
		if  ( ! /$filter/ ) {
			$matchFilter = 0;
			last;
		}
	}
	next if !$matchFilter;
	
	my $msg = new FIXMsg ( 
					delim		=> $delim ,
					simple		=> 0 ,
					showTags	=> \%showTags
				);
	$msg->parse ( $_ );
#	print $msg->dump ();
	
	my $msgType = $msgTypeMap{ $msg->fldVal ( 35 ) };
	my $clOrdID = $msg->fldVal ( 11 );
	my $origClOrdID = $msg->fldVal ( 41 );
	
	if ( $origClOrdID ) {
		if ( $origClOrdID eq $clOrdID ) {
			print STDERR "ClOrdID [$clOrdID] same as predecessor\n";
		}
		else {
			push @{ $clOrdIDsByOrig{ $origClOrdID } } , $clOrdID;
		}
	}
	$msgTypeByClOrdID{ $clOrdID } = $msgType;
	push @{ $clOrdIDsByMsgType{ $msgType } } , $clOrdID;
		
#	print "[$msgType] [$clOrdID] [$origClOrdID]\n";

	$msg->init;
}

foreach my $clOrdID ( @{ $clOrdIDsByMsgType{ 'N' } } ) {
	print mkOrderChain ( $clOrdID , \%clOrdIDsByOrig , \%msgTypeByClOrdID ) , "\n";
}		
