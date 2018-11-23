#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Cwd;

use File::Basename;
use lib dirname $0;

my $scriptName = basename $0;

sub usageAndExit {
	print STDERR "Usage : $scriptName -c configDir -p process -o outputDir [-l logDir]\n";
	print STDERR "logDir defaults to outputDir\n";
	exit 1;
}

sub findJava {
	my ( $dlRoot ) = @_;
	if ( -f "${dlRoot}/Java/bin/java.exe" ) {
		return "${dlRoot}/java.exe";
	}

	my $javaFinder = ( glob ( "\"${dlRoot}/bin/dataloader*-java-home.exe\"" ) )[ 0 ];
	if ( !$javaFinder ) {
		print STDERR "No Java finder utility dataloader*-java-home.exe in Dataloader dir [$dlRoot/bin].\n";
		return;
	}
	
	my $curDir = getcwd;
	chdir "${dlRoot}/bin" or die "Could not change dir to [${dlRoot}/bin] : $!"; 
	open CMD , "$javaFinder" . " |" or die "Cannot run Dataloader finder cmd [$javaFinder] : $!";
	chomp ( my $javaHome= <CMD> );
	close CMD;
	chdir "$curDir";
	
	return "${javaHome}/bin/java";
}	

sub mkXMLFile {
	my ( $tmplFile , $xmlFile , $outputDir , $logDir ) = @_;
	
	local $/ = undef;
	
	my ( $sec , $min , $hour , $mday , $mon , $year , undef , undef , undef ) = localtime ( time );
	my $dateStamp = sprintf ( "%04d%02d%02d" , $year + 1900 , $mon + 1 , $mday );
	my $timeStamp = sprintf ( "%02d%02d%02d" , $hour , $min , $sec );
	
	open TMPL , $tmplFile or die "Cannot open template file [$tmplFile]: $!";
	my $tmplCont = <TMPL>;
	close TMPL;
	
	open XML , ">" . $xmlFile or die "Cannot open XML file [$xmlFile] for writing: $!";
	
	$tmplCont =~ s/#DATESTAMP#/$dateStamp/g;
	$tmplCont =~ s/#TIMESTAMP#/$timeStamp/g;
	$tmplCont =~ s/#OUTPUT_DIR#/$outputDir/g;
	$tmplCont =~ s/#LOG_DIR#/$logDir/g;
	
	print XML $tmplCont;
	close XML;
}

# Validate the environment.
# -------------------------
my $dlRoot = $ENV{ DATALOADER_ROOT };
if ( !$dlRoot ) {
	print STDERR "Please set the DATALOADER_ROOT environment variable to the root of your Dataloader install (e.g. C:/Program Files (x86)/Salesforce.com/Data Loader).\n";
	exit 1;
}
if ( ! -d $dlRoot ) {
	print STDERR "Invalid DATALOADER_ROOT environment variable [$dlRoot]\n";
	exit 1;
}

# Find the key jar file.
# ----------------------
my @jarFiles = glob ( "\"" . $dlRoot . "/dataloader*.jar\"" );
if ( !@jarFiles ) {
	print STDERR "No dataloader*.jar file in DATALOADER_ROOT directory [$dlRoot]\n";
	exit 1;
}
elsif ( scalar @jarFiles > 1 ) {
	print STDERR "Multiple dataloader*.jar files in DATALOADER_ROOT directory [$dlRoot]\n";
	print STDERR "Please remove extraneous jar files.\n";
	exit 1;
}
my $dlJarFile = $jarFiles[ 0 ];

my ( $configDir , $outputDir , $logDir , $process );

my $xmlFile = "process-conf.xml";
my $xmlTemplFile = "${xmlFile}.tmpl";
my $cfgPropFile = "config.properties";

# Get command line options.
# -------------------------
GetOptions ( 
	'c=s'	=> \$configDir ,
	'p=s'	=> \$process ,
	'o=s'	=> \$outputDir ,
	'l=s'	=> \$logDir ,
) or usageAndExit;

usageAndExit if ( !$configDir || !$process || !$outputDir );
$logDir = $outputDir if !$logDir;

# Validate directories and their contents.
# ----------------------------------------
if ( ! -d "$configDir" ) {
	print STDERR "Config directory [$configDir] does not exist.\n";
	exit 1;
}
if ( ! -w $configDir ) {
	print STDERR "Config directory [$configDir] is not writeable.\n";
	exit 1;
}
if ( ! -f "$configDir/$xmlTemplFile" ) {
	print STDERR "No template file [$xmlTemplFile] in config directory [$configDir].\n";
	exit 1;
}
if ( ! -f "$configDir/$cfgPropFile" ) {
	print STDERR "No properties file [$cfgPropFile] in config directory [$configDir].\n";
	exit 1;
}

if ( ! -d $outputDir || ! -r $outputDir ) {
	print STDERR "Output directory [$outputDir] does not exist or is not writeable.\n";
	exit 1;
}
if ( ! -d $logDir || ! -r $logDir ) {
	print STDERR "Log directory [$logDir] does not exist or is not writeable.\n";
	exit 1;
}

# Create the process XML file from its template.
# ----------------------------------------------
mkXMLFile ( "$configDir/$xmlTemplFile" , "$configDir/$xmlFile" , $outputDir , $logDir );

my $javaCmd = findJava ( $dlRoot );
print "JAVA CMD IS : [$javaCmd]\n";
if ( !$javaCmd ) {
	print STDERR "Could not determine Java command.\n";
	exit 1;
}

# Construct the command line.
# ---------------------------
my $dlCmd = "\"$javaCmd\" -cp \"${dlJarFile}\" -Dsalesforce.config.dir=\"$configDir\" com.salesforce.dataloader.process.ProcessRunner process.name=${process}";

print "$dlCmd\n";

# Run the cmd.
# ------------
$| = 1;

open CMD , $dlCmd . " |" or die "Cannot run Dataloader command: $!";
while ( <CMD> ) {
	print;
}
close CMD;
