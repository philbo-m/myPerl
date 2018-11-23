#!c:/perl/bin/perl

use strict;
use File::Basename;
use lib dirname $0;

use STAMP;

sub incrTS {
	my ( $ts , $incr ) = @_;	# --- ( HH:MM:SS.mm , SS ) ---
	my ( $h , $m , $s , $ms ) = split /[:.]/ , $ts;
	my $tv = ( $h * 3600 ) + ( $m * 60 ) + $s + $incr;
	$h = int ( $tv / 3600 );
	$m = int ( ( $tv % 3600 ) / 60 );
	$s = $tv % 60;
	
	return sprintf ( "%02d:%02d:%02d:%02d" , $h , $m , $s , $ms );
}
	
sub getMsgs {
	my ( $fh , $tsLimit ) = @_;
	
	my %msgsByTime = ();
	
	while ( <$fh> ) {
	
#  0- 4	Time,File Type,MemberFirm,BusinessClass,BusinessAction,
#  5- 9	Symbol,FileName,AccountId,AccountType,OrderNumber,
# 10-14	ConfirmationType,Price,Volume,UserId,UserOrderId,
# 15-19	ActionSource,DestAddress,GatewayId,Jitney,RefUserOrderId,
# 20-24	SourceAddress,SequenceNumber,OriginalSequenceNumber,Uniquekey,QEngRespTime,
# 25	MessageDetails

		chomp;
		my ( $ts , $msg ) = ( split /,/ )[ 0 , 25 ];
		next if $ts eq 'Time';
		
		$ts =~ s/^'.*\s(.*)'$/$1/;
		last if $ts gt $tsLimit;
		
		push @{ $msgsByTime{ $ts } } , $msg;
	}
	
	return \%msgsByTime;
}

sub auditMsgs {
	my ( $stamp , $msgsByTime , $bboBySym ) = @_;

	my $fldPtrn = "^(" . join ( "|" , qw ( 6 41 55 56 179 180 ) ) . ")=";

	foreach my $ts ( sort keys %$msgsByTime ) {
		foreach my $msg ( @{ $$msgsByTime{ $ts } } ) {
			my $fldMap = $stamp->getFlds ( $msg , $fldPtrn );
			
			my $busClass = $$fldMap{ BusinessClass };
			my $sym = $$fldMap{ Symbol };
			
			if ( $busClass =~ /IntQuote/ ) {
				
				my $bb = $$fldMap{ BidPrice };
				my $ba = $$fldMap{ AskPrice };
				$$bboBySym{ $sym }{ $busClass }{ BID } = $bb;
				$$bboBySym{ $sym }{ $busClass }{ ASK } = $ba;
				print "$ts,$sym,$busClass,$bb,$ba\n";
			}
			else {
				my $trdPrice = $$fldMap{ Price };
				my $ABB = $$bboBySym{ $sym }{ ABBOIntQuote }{ BID };
				my $ABO = $$bboBySym{ $sym }{ ABBOIntQuote }{ ASK };
				print "$ts,$sym,TRADE,$ABB,$ABO,$trdPrice,";
				if ( $trdPrice > $ABO || $trdPrice < $ABB ) {
					print "TRADETHROUGH";
				}
				print "\n";
			}
		}
	}
}

my $STAMP = new STAMP;

my $startTS = "08:00:00.00";
my $endTS = "11:44:00.000";

my @fhList = ();
foreach my $inFile ( @ARGV ) {
	open ( my $fh , $inFile ) or die ( "Cannot open $inFile : $!" );
	push @fhList , $fh;
}

my %bboBySym = ();

while ( 1 ) {
	$startTS = incrTS ( $startTS , 60 );
	print STDERR "...$startTS...\n";
	last if $startTS gt $endTS;
	
	my %msgsByTime = ();
	foreach my $fh ( @fhList ) {
		my $fhMsgsByTime = getMsgs ( $fh , $startTS );
		foreach my $ts ( keys %$fhMsgsByTime ) {
			push @{ $msgsByTime{ $ts } } , @{ $$fhMsgsByTime{ $ts } };
		}
	}
	auditMsgs ( $STAMP , \%msgsByTime , \%bboBySym );
	
}
					
exit;	