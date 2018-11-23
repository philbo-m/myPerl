#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use File::Basename;

my $PROGNAME = basename $0;
my ( $sec , $min , $hr , $mday , $mon , $year ) = ( localtime () )[ 0 .. 5 ];
my $now = sprintf "%4d%02d%02d_%02d%02d%02d" , $year + 1900 , $mon + 1, $mday , $hr , $min , $sec;

sub usageAndExit {
	print STDERR "Usage: $PROGNAME -h remoteHost -u remoteUser -p remotePasswd [-r remoteDir] [-l localDir] [-g logDir] [-f files]\n";
	exit 1;
}

my ( $remHost , $remUser , $remPasswd , $remDir , $lclDir , $logDir , $files );
my $purgeRem;

GetOptions ( 
	'h=s'	=> \$remHost ,
	'u=s'	=> \$remUser ,
	'p=s'	=> \$remPasswd ,
	'r=s'	=> \$remDir ,
	'l=s'	=> \$lclDir ,
	'g=s'	=> \$logDir ,
	'f=s'	=> \$files ,
	'purge'	=> \$purgeRem
) or die;
print "[$remHost] [$remUser] [$remPasswd]\n";
usageAndExit if ( !$remHost || !$remUser || !$remPasswd );

$files = "*" if !$files;
$remDir = "." if !$remDir;
$lclDir = "." if !$lclDir;
$logDir = $lclDir if !$logDir;

if ( ! -d $lclDir || ! -w $lclDir ) {
	die ( "Local directory [$lclDir] not writeable" );
}
if ( ! -d $logDir || ! -w $logDir ) {
	die ( "Log directory [$logDir] not writeable" );
}
my $logFile = "$logDir/$PROGNAME.$now.log";

# Confirm the existence of the remote folder.
# -------------------------------------------
print STDERR "Confirming existence of $remHost:$remDir...\n";

open ( FTP , "| ftp -n -v > $logFile" ) or die "Could not initiate FTP : $!";
print FTP "open $remHost\n";
print FTP "user $remUser $remPasswd\n";
print FTP "cd $remDir\n";
print FTP "pwd\n";
print FTP "ls\n";
print FTP "quit\n";
close FTP;

my $remDirOK = 0;
open LOG , $logFile;
while ( <LOG> ) {
	chomp;
	if ( /Directory successfully changed/ ) {
		$remDirOK = 1;
		last;
	}
}
close LOG;

if ( !$remDirOK ) {
	print STDERR "Error : Remote dir [$remDir] not accessible\n";
	exit 1;
}

# Remember the sizes of the files in the remote folder.
# -----------------------------------------------------
my %remFileMap = ();

open LOG , $logFile;
while ( <LOG> ) {
	chomp;
	next if ! /^[-rwx]{10}\s/;
	my @flds = split /\s+/;
	my $size = $flds[ 4 ];
	my $file = $flds[ $#flds ];
	$remFileMap{ $file } = $size;
}
close LOG;

# Grab the contents of the remote folder and remember their sizes.
# ----------------------------------------------------------------
print STDERR "Retrieving files [$files] from $remHost:$remDir...\n";

open ( FTP , "| ftp -n -v > $logFile" ) or die "Could not initiate FTP : $!";
print FTP "open $remHost\n";
print FTP "user $remUser $remPasswd\n";
print FTP "cd $remDir\n";
print FTP "lcd $lclDir\n";
print FTP "binary\n";
print FTP "prompt off\n";
print FTP "mget $files\n";
print FTP "quit\n";
close FTP;

# Retrieve the files retrieved (might have been wildcarded) from the FTP logfile.
# -------------------------------------------------------------------------------
my @filesXferred = ();
open LOG , $logFile;
while ( <LOG> ) {
	if ( /^local.* remote: (.*)$/ ) {
		push @filesXferred , $1;
	}
}
close LOG;
	
print STDERR "Retrieved files:\n" , join ( "\n" , @filesXferred ) , "\n";

if ( !scalar @filesXferred ) {
	print STDERR "No files matching [$files] retrieved from $remHost:$remDir.\n";
	exit;
}

# Compare the file sizes to those of the transferred files.
# ---------------------------------------------------------
print STDERR "Validating retrieval of files in $remHost:$remDir...\n";

my $isError = 0;
my @purgeFiles = ();
foreach my $file ( @filesXferred ) {
	my $remSize = $remFileMap{ $file };
	my $size = ( stat "$lclDir/$file" )[ 7 ];
	
	if ( $remSize != $size ) {
		print STDERR "File size mismatch : [$file] remote [$remSize] local [$size]\n";
		$isError = 1;
	}
	else {
		print STDERR "File size OK : [$file] [$remSize]\n";
		push @purgeFiles , $file;
	}
}

if ( @purgeFiles && $purgeRem ) {
	print STDERR "Purging remote files...\n";
	open ( FTP , "| ftp -n" ) or die "Could not initiate FTP : $!";
	print FTP "open $remHost\n";
	print FTP "user $remUser $remPasswd\n";
	print FTP "cd $remDir\n";
	foreach my $file ( @purgeFiles ) {
		print FTP "delete $file\n";
	}
	print FTP "quit\n";
}

exit $isError;