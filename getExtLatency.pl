#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

sub tsDiff { 
	my ( $ts0 , $ts1 ) = @_;	# --- HH:MM:SS.mmmmmm ---
	my @ts = ();
	foreach ( $ts0 , $ts1 ) {
		my @tp = split ( /^(..):(..):(..)\.(.+)$/ );
		push @ts , ( $tp[ 1 ] * 60 * 60 * 1000000 ) + ( $tp[ 2 ] * 60 * 1000000 ) + ( $tp[ 3 ] * 1000000 ) + $tp[ 4 ];
	}
	return abs ( $ts[ 1 ] - $ts[ 0 ] );
}

my %ignoreMsgs = map { $_ => 1 } qw ( 0 1 2 4 5 A MC MR f);
my %toMktMsgs = map { $_ => 1 } qw ( D F G );

my $llSymFile;

GetOptions ( 
	'l=s'	=> \$llSymFile
) or die;

if ( !$llSymFile || ! -f $llSymFile ) {
	print STDERR "Invalid LL Symbol file [$llSymFile]\n";
	exit 1;
}

my %llSymMap = ();
open LL , $llSymFile or die "Cannot open LL Symbol file [$llSymFile]";
while ( <LL> ) {
	chomp;
	my ( $sym , undef ) = split /,/;
	$llSymMap{ $sym } = 1;
}
close LL;

my %msgMap = ();
my %llMap = ();

while ( <> ) {

#	ULLINK-specific pattern matching stuff.
#	---------------------------------------
	print STDERR "$.\n" if ( !( $. % 100000 ) );
	
	next if ( ! /\s(Sending|Receiving)\s:\s/ || /\s<.*\/>$/ || /\[I_/ || /_RELAY/ );
	chomp;
	
	my ( $date , $time , $thread , $plugin , $lvl , $dir , undef , $msg ) = split ( /\s+/ , $_ , 8 );
	
	my @msg = split ( /(?:\||^)(\d+)=/ , $msg );
	shift @msg;
	my %msg = @msg;
	
	( $msg{ "TS" } = $time ) =~ s/_//g;
	$plugin =~ s/^\[O_(.*)\]/$1/;
	$msg{ "PLUGIN" } = $plugin;
	
	my $msgType = $msg{ "35" };
	my $dur = $msg{ "59" };
	my $clOrdID = $msg{ "11" };
	my $sym = $msg{ "55" };
	
	next if !$clOrdID;
		
	next if exists $ignoreMsgs{ $msgType };

	my $isToMkt = ( exists $toMktMsgs{ $msgType } ? 1 : 0 );
	if ( $isToMkt ) {
		$msgMap{ $plugin }{ $clOrdID } = \%msg;
		my $longLife = $msg{ "7735" };
		my $undisp = $msg{ "7726" };

#		Remember long-life orders so we can carve the CFOs/CXLs off into their own buckets.
#		-----------------------------------------------------------------------------------
		if ( $longLife eq "Y" ) {
			print STDERR "[$msgType] [$clOrdID] [$longLife] [$undisp] [" , exists $llSymMap{ $sym } , "]...\n";
		}
		if ( $msgType eq 'D' && $longLife eq "Y" && $undisp ne "Y" && exists $llSymMap{ $sym } ) {
			$llMap{ $clOrdID } = 1;
			print STDERR "LL new order [$sym] [$clOrdID]...\n";
		}
		elsif ( $msgType =~ /[FG]/ ) {
			my $origClOrdID = $msg{ "41" };
			if ( delete $llMap{ $origClOrdID } ) {
				$llMap{ $clOrdID } = 1;
#				print STDERR "LL CFO/CXL [$msgType] [$sym] [$origClOrdID] --> [$clOrdID]...\n";
			}
		}
	}
	else {
		my $origMsg = $msgMap{ $plugin }{ $clOrdID };
		if ( $origMsg ) {
			my $execType = $msg{ "150" };
			my $longLife = exists $llMap{ $clOrdID };
			my $dispPlugin = $msg{ "PLUGIN" };
			if ( $dispPlugin =~ /ALPHA/ && $msg{ "7734" } eq 'Y' ) {
				$dispPlugin .= "_S";
			}
			elsif ( $longLife ) {
				$dispPlugin .= "_L";
#				print STDERR "LL EXEC [$execType] [$sym] [$clOrdID]...\n";
			}
			print join ( "," ,
					(
						$dispPlugin ,
						$sym ,
						$clOrdID ,
						$$origMsg{ "100" } ,
						$$origMsg{ "35" } ,
						$msgType ,
						$execType ,
						$$origMsg{ "TS" } ,
						$msg{ "TS" } ,
						tsDiff ( $msg{ "TS" } , $$origMsg{ "TS" } )
					)
				) , "\n";
			if ( $execType !~ /^[6AE]$/ ) {	# --- everything but the 'Pending' msgs ---
				delete $msgMap{ $plugin }{ $clOrdID };
			}
		}
	}
}