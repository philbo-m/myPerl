#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use FIXMsg;

sub readBuf {
	
	my ( $delim , $simple , $ignoreTrailingZeros , $ignoreMsgs , $verbose ) = @_;
	
	my @msgBufs = ( [] , [] );
	
	while ( <> ) {
		
#		ULLINK-specific pattern matching stuff.
#		---------------------------------------
		next if ( ! /\s(Sending|Receiving)\s:\s/ || /\s<.*\/>$/ || /_RELAY/ );
		
		chomp;
		
		my $msg = new FIXMsg ( delim => $delim );
		$msg->parse ( $_ );

#		Fld [35]MsgType is used to decide whether to ignore msgs.
#		---------------------------------------------------------
		next if exists $$ignoreMsgs{ $msg->fldVal ( 35 ) };
		
		my $isToMkt = ( $msg->isToMkt ? 1 : 0 );
		my $isInbound = $msg->{isInbound};
		my $timeStamp = $msg->{timeStamp};
		my $uniqId = $msg->uniqId;
		
		my $msgBuf = $msgBufs[ $isToMkt ];
		
		my $msgType = $msg->fldVal ( 35 );
		if ( $isInbound ) {
		
#			Inbound msg - add to appropriate buffer.
#			----------------------------------------
			if ( $verbose ) {
				print STDERR "Pushing inbound [$msg->{timeStamp}] [$msgType] [$uniqId] to [$isToMkt] buf\n";
			}
			push @$msgBuf , $msg;
		}
		else {
		
#			Outbound msg - find matching inbound msg in appropriate buffer.
#			---------------------------------------------------------------
			if ( $verbose ) {
				print STDERR "Matching inbound [$msg->{timeStamp}] [$msgType] [$uniqId] vs [$isToMkt] buf\n";
			}
			my $matchMsg = findMatchingMsg ( $msgBuf , $msg , $verbose );
			if ( $matchMsg ) {
				if ( $verbose ) {
					print STDERR "...Found matching [$matchMsg->{timeStamp}]...\n";
				}
				my $cltMsg = ( $isToMkt ? $matchMsg : $msg );
				my $venueMsg = ( $isToMkt ? $msg : $matchMsg );
				cmpMsgs ( $cltMsg , $venueMsg , $simple , $ignoreTrailingZeros );
			}
			else {
				if ( $verbose ) {
					print STDERR "...No match!!\n";
				}
			}
		}
			
	}
}
				
sub xreadBuf {
	my ( $fileHandle , $buf , $delim , $ignoreMsgs ) = @_;

	my $isFirst = 1;
	my $initBufSize = scalar @$buf;
	my ( $startTime , $endTime );
	while ( scalar @$buf < 10000 ) {
		my $rec = readline ( $fileHandle );
		if ( ! $rec ) {
			return 0;
		}
		
		chomp $rec;
		my $msg = new FIXMsg ( delim => $delim );
		$msg->parse ( $rec );
		
#		Fld [35]MsgType is used to decide whether to ignore msgs.
#		---------------------------------------------------------
		if ( !exists $$ignoreMsgs{ $msg->fldVal ( 35 ) } ) {	
#			print "[$rec]\n";
			if ( $isFirst ) {
				$startTime = $msg->{timeStamp};
				$isFirst = 0;
			}
			push @$buf , $msg;
		}
	}
	$endTime = $$buf[ $#$buf ]->{timeStamp};
	print STDERR "...[$startTime]->[$endTime] (" , scalar ( @$buf ) - $initBufSize , ") recs\n";
	
	return 1;
}

sub earlierOf {
	my @msgs = @_;
	return ( $msgs[ 0 ]->{timeStamp} lt $msgs[ 1 ]->{timeStamp} ? 0 : 1 );
}


sub tsDiff { 
	my ( $ts0 , $ts1 ) = @_;	# --- HH:MM:SS.mmmmmm ---
	my @ts = ();
	foreach ( $ts0 , $ts1 ) {
		my @tp = split ( /^(..):(..):(..)\.(.+)$/ );
		push @ts , ( $tp[ 1 ] * 60 * 60 * 1000000 ) + ( $tp[ 2 ] * 60 * 1000000 ) + ( $tp[ 3 ] * 1000000 ) + $tp[ 4 ];
	}
	return abs ( $ts[ 1 ] - $ts[ 0 ] );
}

sub findMatchingMsg {
	my ( $buf , $msg , $verbose ) = @_;

	my $msgType = $msg->fldVal ( 35 );
	my $uniqId = $msg->uniqId;
	
	foreach my $bufIdx ( 0 .. $#$buf ) {
		my $bufMsg = $$buf[ $bufIdx ];
		
		if ( $verbose ) {
			print STDERR "Matching [$msg->{timeStamp}] [$msgType] [$uniqId] vs other buf [$bufIdx] [$bufMsg->{timeStamp}] [" , 
							$bufMsg->fldVal ( 35 ) , "] [" , $bufMsg->uniqId , "]\n";
		}
		if ( $bufMsg->fldVal ( 35 ) eq $msgType && $bufMsg->uniqId eq $uniqId ) {
			splice ( @$buf , $bufIdx , 1 );
			return $bufMsg;
		}
	}

	return undef;
}

sub cmpMsgs {
	my ( $msg , $otherMsg , $simple , $ignoreTrailingZeros ) = @_;	# --- $msg must be client-side, $otherMsg venue-side ---
	
	my @ignoreFldList = qw ( 8 49 50 56 57 60 );
	my %ignoreFldMap = map { $_ => 1 } @ignoreFldList;
	
	my @cmpResult = ();
	
	if ( $simple ) {
		push @cmpResult , [ $msg->msgType , $msg->{timeStamp} , $otherMsg->{timeStamp} ,
							tsDiff ( $msg->{timeStamp} , $otherMsg->{timeStamp} ) ];
	}
	else {
		my $cmpResults = $msg->cmp ( $otherMsg , $ignoreTrailingZeros , \%ignoreFldMap );
		foreach my $result ( @$cmpResults ) {
			push @cmpResult , [ $msg->{timeStamp} , $otherMsg->{timeStamp} ,
								$msg->msgType , 
								( defined $$result[ 1 ] && defined $$result[ 2 ] ? 'FLD DIFF' 
									: ( defined $$result[ 1 ] ? 'CLT FLD ONLY' : 'MKT FLD ONLY' ) ) ,
								@$result ];
		}
	}
		
	foreach my $result ( @cmpResult ) {
		print join ( "," , @$result ) , "\n";
	}
}
		
my $delim = "";
my ( $cltSideFile , $mktSideFile , $simple , $ignoreTrailingZeros , $verbose );

GetOptions ( 
	'd=s'	=> \$delim ,
	's'		=> \$simple ,
	'z'		=> \$ignoreTrailingZeros ,
	'v'		=> \$verbose
) or die;

my @msgBufs = ( [] , [] );

my %ignoreMsgs = map { $_ => 1 } qw ( 0 1 2 4 5 A );

if ( $simple ) {
	print "Message,Clt Side Time,Mkt Side Time,Time Diff\n";
}
else {
	print "Clt Side Time,Mkt Side Time,Message,Code,Tag,Clt Side Val,Mkt Side Val\n";
}

local $| = 1;

readBuf ( $delim , $simple , $ignoreTrailingZeros , \%ignoreMsgs , $verbose );

exit;

__DATA__

# Read in 10,000-msg chunks.
# --------------------------
while ( $inFile1 || $inFile2 ) {
	if ( $inFile1 ) {
		print STDERR "Reading from $cltSideFile...\n";
		if ( !readBuf ( \*FILE1 , $msgBufs[ 0 ] , $delim , \%ignoreMsgs ) ) {
			print STDERR "Reached end of $cltSideFile\n";
			$inFile1 = 0;
		}
	}
	if ( $inFile2 ) {
		print STDERR "Reading from $mktSideFile...\n";
		if ( !readBuf ( \*FILE2 , $msgBufs[ 1 ] , $delim , \%ignoreMsgs ) ) {
			print STDERR "Reached end of $mktSideFile\n";
			$inFile2 = 0;
		}
	}
	
	cmpBufs ( \@msgBufs , $simple , $ignoreTrailingZeros , 0 , $verbose );
}

cmpBufs ( \@msgBufs , $simple , $ignoreTrailingZeros , 1 , $verbose );

exit;