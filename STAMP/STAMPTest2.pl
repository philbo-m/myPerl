#!c:/perl/bin/perl

use strict;
use Data::Dumper;
use Getopt::Long;

use STAMP::STAMPBook;
use SymbolBook;

my $STAMPFile;

our $PRE_OPEN_THRESH_TIME = "09:25:00.000000000";

our %symInfoMap = ();

our $debug;

sub tsDiff { 
	my ( $ts0 , $ts1 ) = @_;	# --- HH:MM:SS.mmmmmmmmm ---
	my @ts = ();
	foreach ( $ts0 , $ts1 ) {
		my @tp = split ( /^(\d\d):(\d\d):(\d\d\.\d+)$/ );
		push @ts , ( $tp[ 1 ] * 60 * 60 ) + ( $tp[ 2 ] * 60 ) + $tp[ 3 ];
#		print STDERR "TSDIFF : ts [$_] [$ts[ $#ts ]]\n";
	}
	return ( $ts[ 1 ] - $ts[ 0 ] );
}

sub getSymInfo {
	my ( $sym ) = @_;
	my $symInfo = $symInfoMap{ $sym };
	if ( !$symInfo ) {
		$symInfo = {
			Quote			=> undef ,
			QuoteTime		=> undef ,
			Presence		=> undef ,
			MktState		=> undef ,
			LastTrade		=> undef ,
			Total			=> { Vol => 0 , Count => 0 } ,
			LL				=> { Vol => 0 , Count => 0 } ,
			AtNBBO			=> undef
		};
		$symInfoMap{ $sym } = $symInfo;
	}
	return $symInfo;
}

sub isOpen {
	my ( $mktState ) = @_;
	return ( $mktState eq 'Open' || $mktState eq 'MOC Imbalance' );
}

sub orderTest {
	my ( $timeStamp , $symBook , $rawMsg ) = @_;
	
	print STDERR Dumper ( $rawMsg ) , "\n";
}

sub mktStateTest {
	my ( $timeStamp , $symBook ) = @_;
	
	print STDERR "[$timeStamp] : MKT STATE [$symBook->{Sym}] NOW [$symBook->{MktState}]...\n";
	my $symInfo = getSymInfo ( $symBook->{Sym} );
	
#	If transitioning from Pre-open to Opening, process the final Pre-open interval.
#	If transitioning from Open/MOC Imbalance to CCP Determination, process the final Open interval.
#	-----------------------------------------------------------------------------------------------
	if ( $symBook->{MktState} eq 'Opening' ) {
		quoteTest ( $timeStamp , 1 , $symBook );
	}
	elsif ( $symBook->{MktState} eq 'CCP Determination' ) {
		quoteTest ( $timeStamp , 1 , $symBook );
	}
		
	$symInfo->{MktState} = $symBook->{MktState};
	
	if ( $symBook->{MktState} eq "Open" ) {
		$symInfo->{QuoteTime} = $timeStamp;
	}
}

sub symStatusTest {
	my ( $timeStamp , $symBook ) = @_;
	
	my $symInfo = getSymInfo ( $symBook->{Sym} );
	$symInfo->{MGFQty} = $symBook->{MGFQty};
}

GetOptions ( 
	'd'		=> \$debug
);

$STAMPFile = $ARGV[ 0 ] if !$STAMPFile;

# print "QUOTE,Sym,StartTime,EndTime,Duration,Total Orders,Total Vol,LL Orders,LL Vol\n";

my $STAMPBook = new STAMP::STAMPBook ( File => $STAMPFile ,
										BuildBook			=> 0 ,
										OrderCallback		=> \&orderTest ,
										Debug				=> $debug 
									);

$STAMPBook->run;