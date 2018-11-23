#!c:/perl/bin/perl

use strict;
use Getopt::Long;

sub tsVal {
	my ( $ts ) = @_;	# --- hh:mm:ss.mmmmmm ---
	my ( $hh , $mm , $ss ) = split /:/ , $ts;
	return ( ( $hh * 3600 ) + ( $mm * 60 ) + $ss ) * 1000000;
}

sub mkTS {
	my ( $tsVal , $keepUSec ) = @_;
	my $usec;
	( $tsVal , $usec ) = ( $tsVal =~ /^(.*)(\d{6})$/ );
	$tsVal = sprintf "%02d:%02d:%02d" , $tsVal / 3600 , ( $tsVal % 3600 ) / 60 , $tsVal % 60;
	if ( $keepUSec ) {
		$tsVal .= "." . $usec;
	}
	return $tsVal;
}

sub tsDiff {
	my ( $t1 , $t2 ) = @_;
	return tsVal ( $t2 ) - tsVal ( $t1 );
}

sub max {
	my ( $a , $b ) = @_;
	return ( $a > $b ? $a : $b );
}

sub allocateBuckets {
	my ( $startTime , $endTime , $sbLen , $bucketSize ) = @_;
	$startTime = tsVal ( $startTime );
	$endTime = tsVal ( $endTime ) - $sbLen;
#	print "Interval [$startTime] - [$endTime], SB len [$sbLen], bucket size [$bucketSize]\n";
	
	my %bucketMap = ();
	return \%bucketMap if $endTime < $startTime;
	
	my $bucket = $startTime - ( $startTime % $bucketSize );
#	print "...start bucket [$bucket] [" , mkTS ( $bucket ) , "]\n";
	$bucketMap{ $bucket } = $bucketSize - ( $startTime % $bucketSize ) - 1;
	
	while ( $bucket + $bucketSize <= $endTime ) {
		$bucket += $bucketSize;
		$bucketMap{ $bucket } = $bucketSize;
	}

	$bucketMap{ $bucket } -= $bucketSize - ( $endTime % $bucketSize ) - 1;
#	print mkTS ( $startTime , 1 ) , "," , mkTS ( $endTime , 1 ) , ",$sbLen : " , join ( "," , map { mkTS ( $_ ) . "=" . $bucketMap{ $_ } } sort keys %bucketMap ) , "\n";
	
	return \%bucketMap;
}

# my $m = allocateBuckets ( "09:30:01.000430" , "09:30:03.047003" , 1000 , 1000000 );
# foreach my $b ( sort keys %$m ) {
#  	print mkTS ( $b ) , " : $$m{ $b }\n";
# }
# exit;

my ( @syms , %syms , $mktHrs );
my $bucketSize;
my @mktHrs = ( "09:30:00" , "16:00:00" );

GetOptions ( 
	's=s'	=> \@syms ,
	'b=s'	=> \$bucketSize ,
	'm=s'	=> \$mktHrs
) or die;

if ( $mktHrs ) {
	if ( $mktHrs !~ /^\d\d:\d\d:\d\d,\d\d:\d\d:\d\d$/ ) {
		print STDERR "Invalid market hrs \"$mktHrs\"\n";
		exit 1;
	}
	@mktHrs = split /,/ , $mktHrs;
}
@mktHrs = map { $_ . ".000000" } @mktHrs;

# Can specify symbols directly, or as a file of syms (one sym, by itself, per row).
# ---------------------------------------------------------------------------------
@syms = split ( /,/ , join ( "," , @syms ) );

foreach my $sym ( @syms ) {
	if ( -f $sym ) {
		open SYMFILE , $sym;
		foreach ( <SYMFILE> ) {
			chomp;
			$syms{ $_ } = 1;
		}
		close SYMFILE;
	}
	else {
		$syms{ $sym } = 1;
	}
}

# Timestamp,Symbol,ATS Timestamp,BBO Timestamp,Dest Timestamp,
# Best Bid,Best Ask,Best Bid Changed,Best Ask Changed,Reason,
# Exchange,Prev State,CXC State,CXC Best Bid,CXC Best Ask,
# CX2 State,CX2 Best Bid,CX2 Best Ask,OMG State,OMG Best Bid,
# OMG Best Ask,PT State,PT Best Bid,PT Best Ask,SEL State,
# SEL Best Bid,SEL Best Ask,TVX State,TVX Best Bid,TVX Best Ask,
# TX1 State,TX1 Best Bid,TX1 Best Ask,TX2 State,TX2 Best Bid,
# TX2 Best Ask,LYN State,LYN Best Bid,LYN Best Ask

# --- TMXS top 100 ---
# my @syms = qw ( TRP VRX NVC AEM HQU HVI MG RGL CNR HVU FNV ENB CP HXU TKM RY AYA BNS CNQ THI ENL CTC.A BMO CM CVE POW.PR.C CCT CTY SES AGU NDQ HSU MX SU CNU HZD RFP HXS GIL SAP SW IMO ECP HXS.U PPL BTE CYB FM MEG GIB.A XQQ TD L XWD ARX G UHB KEY GDC CBQ.A ZQQ XUS SNC WN PEG SLW XSU CCL.B HBD MRU RID ACD BAM.A NA POT WPT MKP PKI ACQ SWC.U FSV CPG XRB IPL XVX MNS TCL.B HGD UNS POW PRE PBH CCO DOL ERF DII.B POU BCE.PR.A TOU LUP );

# --- TMXS top 46 between 9:30 and 9:50 ---
# my @syms = qw ( RID GDC VRX HVI TRP HQU RBS CTY ENB AEM CNR HXU THI AGU SU BNS TKM CNQ POT HVU FNV HSU RY TD CYB XSU MG BMO HGD HXS HXS.U CCT CVE RGL CM AEI G GC FM HXT.U SWC.U CTC.A SES PKI BSC MX );

# --- TMXS top 46 between 15:30 and 16:00 ---
# my @syms = qw ( POW.PR.C BUI AYA MCR XVX NVC CCL.B IPL CTC.A MG FNV SAP VRX THI SES RGL FSV ATD.B CM TKM PXT POU CP WN BAM.A CNR KEY BMO UFS HQU PPL ECP GIL WFT PRE BEI.UN ENL BEP.UN RET CAA MX ENB HVI MRU CCT VET );

# --- Top 5 TSX syms by volume ---
# my @syms = qw ( BTO MFC TRP BBD.B RIO );

# --- Top 5 TSXV syms by msg volume ---
# my @syms = qw ( PRC KWG MVN SCR BBI );

# --- XATS top 100 ---
# my @syms = qw ( PKI.DB.A TRP VRX NVC AEM HVI HQU MG CAM.DB RGL CNR HVU FNV PPL.DB.F HXU ENB CP RY TRZ.A CNQ PPL.DB.C BNS SPB.DB.G AYA TKM BMO UNS THI HGD ENL CM CTC.A CVE CCT SU AGU POW.PR.C MX SES CTY NDQ HSU PBH HXS CNU SW RFP CYB GIL PPL IMO SAP HXS.U MNS HZD TD MEG GIB.A BTE FM ECP ARX XQQ L MKP XWD G TA.PR.F BUI GDC CCL.B SNC SLW UHB XSU WN NA KEY XUS CBQ.A CPG PEG MRU POT BAM.A HBD RID ACD FSV ZQQ PKI ECI.DB WPT MRD ACQ DII.B SWC.U IPL XVX POW );

# --- XATS top 46 between 9:30 and 9:50 ---
# my @syms = qw ( POW.PR.C BUI PKI.DB.A SPB.DB.G MRD AYA CCL.B XVX MCR MG IPL NVC PPL.DB.F CTC.A VRX FNV SAP THI PPL.DB.C SES FSV CM ATD.B PXT RGL POU BYD.DB TKM BMO CNR WN CP BAM.A KEY HQU UFS PPL RET PBH WFT PRE GIL ECP BEP.UN BEI.UN ENL );

# --- XATS top 46 between 15:30 and 16:00 ---
# my @syms = qw ( PKI.DB.A RID GDC CAM.DB VRX TRZ.A TRP HQU HVI RBS AEM ENB CTY HXU CNR THI HGD AGU HXS SU CNQ BNS TKM HXS.U HVU POT FNV HSU RY TD CYB BMO CVE XSU MG CCT G CM AEI RGL CTC.A GC X HXT.U FM PPL.DB.C );

my @sbList = ( 1000 , 2000 , 3000 , 4000 , 5000 , 6000 , 7000 , 8000 , 9000 , 10000 , 
				20000 , 30000 , 40000 , 50000 , 60000 , 70000 , 80000 , 90000 , 100000 , 
				200000 , 300000 , 400000 , 500000 , 1000000 , 2000000 , 3000000 , 4000000 , 5000000 );
@sbList = ( 3000 , 5000 , 10000 , 25000 , 50000 , 100000 );

my %syms = map { $_ => 1 } @syms;

my %edgeMap = ();			# --- sym -> timeOfLastEdge
my %edgeCountMap = ();		# --- sym -> numOfEdges
my %willFitMap = ();		# --- sym -> speedBumpLen -> numSpeedBumpsThatWillFit
my %bucketMap = ();			# --- sym -> speedBumpLen -> bucket -> numSpeedBumpsFittingInBucket

while ( <> ) {
	chomp ; s/"//g;
	
	my ( $sym , $timeStamp , $bestBidChanged , $bestAskChanged ) = ( split /,/ )[ 1 , 4 , 7 , 8 ];
	next if %syms && !exists $syms{ $sym };
	
	$timeStamp =~ s/^\d{8}\s+(\d{2}:\d{2}:\d{2}\.\d{6})\s+.*$/$1/;
	next if ( $timeStamp lt $mktHrs[ 0 ] || $timeStamp gt $mktHrs[ 1 ] );
	
	my $lastEdge = $edgeMap{ $sym };
	$edgeMap{ $sym } = $timeStamp;
	$edgeCountMap{ $sym }++;
	
	$lastEdge = $mktHrs[ 0 ] if !$lastEdge;
	my $duration = tsDiff ( $lastEdge , $timeStamp );
	foreach my $sbLen ( @sbList ) {
		$willFitMap{ $sym }{ $sbLen } += max ( $duration - $sbLen + 1 , 0 );
		if ( $bucketSize ) {
			my $edgeMap = allocateBuckets ( $lastEdge , $timeStamp , $sbLen , $bucketSize );
			foreach my $bucket ( keys %$edgeMap ) {
				$bucketMap{ $sym }{ $bucket }{ $sbLen } += $$edgeMap{ $bucket };
#				print "$lastEdge - $timeStamp : Bucket [$sym] [" , mkTS ( $bucket ) , "] [$sbLen] now [$bucketMap{ $sym }{ $bucket }{ $sbLen }]\n";
			}
		}
	}
#	print "Last edge for [$sym] now [$edgeMap{ $sym }]\n";
}

# Close off final intervals (unclosed by end of market hours).
# ------------------------------------------------------------
my $timeStamp = $mktHrs[ 1 ];
foreach my $sym ( sort keys %edgeMap ) {
	my $duration = tsDiff ( $edgeMap{ $sym } , $timeStamp );
	foreach my $sbLen ( @sbList ) {
		$willFitMap{ $sym }{ $sbLen } += max ( $duration - $sbLen + 1 , 0 );
		if ( $bucketSize ) {
			my $edgeMap = allocateBuckets ( $edgeMap{ $sym } , $timeStamp , $sbLen , $bucketSize );
			foreach my $bucket ( keys %$edgeMap ) {
				$bucketMap{ $sym }{ $bucket }{ $sbLen } += $$edgeMap{ $bucket };
			}
		}
	}
}	

my $totDuration = tsDiff ( $mktHrs[ 0 ] , $mktHrs[ 1 ] );
my @bucketList = ();
for ( my $bucket = tsVal ( $mktHrs[ 0 ] ) ; $bucket <= tsVal ( $mktHrs[ 1 ] ) ; $bucket += $bucketSize ) {
	push @bucketList , $bucket;
}

print "Sym,Time," , join ( "," , map { "$_ usec" } @sbList ) , "\n";

foreach my $sym ( sort keys %bucketMap ) {
	foreach my $bucket ( @bucketList ) {
		print "$sym," , mkTS ( $bucket );
		foreach my $sbLen ( @sbList ) {
			printf ",%.2f" , $bucketMap{ $sym }{ $bucket }{ $sbLen } / $bucketSize * 100;
		}
		print "\n";
	}
}

exit;
print "Sym,Events," , join ( "," , @sbList ) , "\n";

foreach my $sym ( sort keys %willFitMap ) {
	print "$sym,$edgeCountMap{ $sym }";
	foreach my $sbLen ( @sbList ) {
		printf ",%.2f" , $willFitMap{ $sym }{ $sbLen } / $totDuration * 100;
	}
	print "\n";
}

__DATA__

my %pctMap = map { $_ => $totDuration } keys %durationMap;

print "Duration (usec)," , join ( "," , sort keys %pctMap ) , "\n";

foreach my $duration ( 0 , sort { $a <=> $b } keys %allDurationMap ) {
	print "$duration";
	foreach my $sym ( sort keys %pctMap ) {
		my $numAtDuration = $durationMap{ $sym }{ $duration };
		$pctMap{ $sym } -= $numAtDuration * ( $duration );
		printf ",%d,%.0f,%.0f,%.2f" , $numAtDuration , $totDuration - $pctMap{ $sym } , $pctMap{ $sym } , $pctMap{ $sym } / $totDuration * 100.;
	}
	print "\n";
}

print "Duration," , join ( "," , sort keys %durationMap ) , "\n";
foreach my $duration ( sort { $a <=> $b } keys %allDurationMap ) {
	printf "%.0f" , $duration;
	foreach my $sym ( sort keys %durationMap ) {
		printf ",%d" , $durationMap{ $sym }{ $duration };
	}
	print "\n";
}

__DATA__
foreach my $sym ( sort keys %intMap ) {
	my ( $totCnt , $avg ) = ( 0 , 0 );
	foreach my $int ( sort { $a <=> $b } keys %{ $intMap{ $sym } } ) {
		my $cnt = $intMap{ $sym }{ $int };
		$totCnt += $cnt;
		$avg += ( $int * $cnt );
		print "$sym,$int,$cnt\n";
	}
	$avg /= $totCnt;
	printf "%s,AVG,%.0f\n" , $sym , $avg;
}
		