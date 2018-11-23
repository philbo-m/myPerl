#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;

use CSV;
use BillingScenario ( qw ( @invalidScenarios ) );

sub dumpBucket {
	my ( $bucket , $attrNames ) = @_;
	return "[$$bucket{ 'ID' } : $$bucket{ 'NAME' }] ["
			. join ( "|" , 
				map { 
					my $attr = $_;
					join ( "," , 
						map { 
							my $val = $$bucket{ 'ATTRS' }{ $attr }{ $_ };
							( $val == 0 ? "<>" : "" ) . "$_";
						} keys %{ $$bucket{ "ATTRS" }{ $attr } } 
					) 
				} @$attrNames 
			)
			. "]";
}

sub dumpScenario {
	my ( $scenario , $attrNames ) = @_;
	return join ( "," , map { exists ( $$scenario{ $_ } ) ? $$scenario{ $_ } : "*" } @$attrNames );
};

sub parseScenarioFile {
	my ( $file , $scenario , $attrVals ) = @_;
	
	open ( FILE , $file ) or die $!;
	while ( <FILE> ) {
		chomp;
		next if ( /^\s*$/ || /^#/ );
		if ( ! /^.+=/ ) {
			print STDERR "Invalid entry [$_] in scenario file - should be KEY=VALUE\n";
			exit 1;
		}
		s/\s//g;
		my ( $attr , $val ) = /^(.+)=(.*)$/;
		if ( !exists $$attrVals{ $attr } ) {
			print STDERR "Invalid attribute [$attr] in scenario file\n";
			exit 1;
		}
		if ( $val ne "*" ) {
			foreach ( split ( /,/ , $val ) ) {
				if ( !exists $$attrVals{ $attr }{ $_ } ) {
					print STDERR "Invalid value [$_] for attribute [$attr] in scenario file\n";
					exit 1;
				}
			}
		}

		$$scenario{ $attr } = $val;
	}
	close FILE;
}		

sub addBucketAttr {
	my ( $bucket , $attrVals , $attrName , $val ) = @_;
	$val =~ s/ //g;
	return if $val eq '';
	my $yesno = ( $val =~ /^<>/ ? 0 : 1 );
	$val =~ s/^<>//g;
	$$bucket{ "ATTRS" }{ $attrName }{ $val } = $yesno;
	$$attrVals{ $attrName }{ $val } = 1;
	if ( $val =~ /^[yY]$/ ) {
		$$attrVals{ $attrName }{ "N" } = 1;
	}
	elsif ( $val =~ /^[nN]$/ ) {
		$$attrVals{ $attrName }{ "Y" } = 1;
	}
}

sub matchAttr {
	my ( $attrName , $attrVal , $bucketValMap ) = @_;
#	print "MATCHING [$attrName=$attrVal] to [" , join ( " , " , map { "$_=$$bucketValMap{ $_ }" } keys %$bucketValMap ) , "]...\n";
	if ( !scalar keys %$bucketValMap ) {
		return 1;
	}
	elsif ( !exists $$bucketValMap{ $attrVal } ) {
		return 0;
	}
	else {
		my $yesno = $$bucketValMap{ $attrVal };
		return $yesno;
	}
}

sub matchBucket {
	my ( $bucket , $scenario , $attrNames ) = @_;
#	print "Bucket " , dumpBucket ( $bucket , $attrNames ) , "\n";
	foreach my $attr ( @$attrNames ) {
		my $scenarioVal = $$scenario{ $attr };
		my $bucketValMap = $$bucket{ "ATTRS" }{ $attr };
		if ( !matchAttr ( $attr , $scenarioVal , $bucketValMap ) ) {
#			print "...[$attr = $scenarioVal] didn't match...\n";
			return 0;
		}
	}
	return 1;
}
		
sub matchScenario {
	my ( $bucketList , $scenario , $attrNames ) = @_;
	foreach my $bucket ( @$bucketList ) {
		if ( matchBucket ( $bucket , $scenario , $attrNames ) ) {
#			print "MATCHED BUCKET [$bucket]\n";
			return $bucket;
		}
	}
	return undef;
}

sub dumpMatch {
	my ( $scenario , $bucketID , $bucketName , $attrNames ) = @_;
	
	print dumpScenario ( $scenario , $attrNames ) , ",$bucketID,$bucketName\n";
}

sub isValidScenario {
	my ( $scenario , $invalidScenarios , $attrNames ) = @_;
	foreach my $invalidScenario ( @$invalidScenarios ) {
		my $invalid = 1;
		foreach my $attr ( keys %$invalidScenario ) {
#			print "Comparing [$attr] [$$scenario{ $attr }] vs [$$invalidScenario{ $attr }] for validity...\n";
			if ( $$scenario{ $attr } ne $$invalidScenario{ $attr } ) {
#				print "...different - scenario is valid\n";
				$invalid = 0;
				last;
			}
		}
		if ( $invalid ) {
			dumpMatch ( $scenario , "Invalid" , join ( " ; " , map { "$_ = $$invalidScenario{ $_ }" } keys %$invalidScenario ) , $attrNames );
			return 0;
		}
	}
	return 1;
}
		
sub testScenarios {
	my ( $bucketList , $masterScenario , $scenario , $attrValMap , $invalidScenarios , $attrNames , $attrNameIdx ) = @_;
	
#	print "testScenarios [" , dumpScenario ( $scenario , $attrNames ) , "]\n";
	if ( $attrNameIdx > $#$attrNames ) {
#		print "...matching scenario... [" , join ( "|" , map { $$scenario{ $_ } } @$attrNames ) , "]\n";
		my $bucket = matchScenario ( $bucketList , $scenario , $attrNames );
		if ( $bucket ) {
			dumpMatch ( $scenario , $$bucket{ 'ID' } , $$bucket{ 'NAME' } , $attrNames );
		}
	}
	else {
		my $attrName = $$attrNames[ $attrNameIdx ];
		my @scenarioVals = split ( /,/ , $$masterScenario{ $attrName } );
		if ( !@scenarioVals ) {
			@scenarioVals = ( '' );
		}
		elsif ( $scenarioVals[ 0 ] eq "*" ) {
			@scenarioVals = keys %{ $$attrValMap{ $attrName } };
		}
#		print "dropping into idx [" , $attrNameIdx + 1 , "] : [" , dumpScenario ( $scenario , $attrNames ) , "] attr [$attrName] = $$masterScenario{ $attrName }\n";
		foreach my $attrVal ( @scenarioVals ) {
#			print "...with [$attrName] = [$attrVal]...\n";
			$$scenario{ $attrName } = $attrVal;
			foreach ( $attrNameIdx + 1 .. $#$attrNames ) {
				$$scenario{ $$attrNames[ $_ ] } = $$masterScenario{ $$attrNames[ $_ ] };
			}
			next if !isValidScenario ( $scenario , $invalidScenarios , $attrNames );
			testScenarios ( $bucketList , $masterScenario , $scenario , $attrValMap , $invalidScenarios , $attrNames , $attrNameIdx + 1 );
		}
	}
}

my $bucketIdIdx = 4;
my $bucketDescIdx = 5;
my $bucketNameIdx = 7;
my $startAttrIdx = 8;
my $endAttrIdx = 36;

my $scenarioFile;

GetOptions ( 
	'f=s'		=> \$scenarioFile
) or die;

if ( $scenarioFile && ! -r $scenarioFile ) {
	die "Cannot open scenario file [$scenarioFile]\n";
}

# Initialize attribute value map with valid values that might not show up in the bucket file.
# -------------------------------------------------------------------------------------------
my %attrVals = (
	SYMBOL_GROUP => {
		"2"		=> 1
	} ,
	ACTIVE_PASSIVE => {
		"A"		=> 1 ,
		"P"		=> 1
	} ,
	O_ACTIVE_PASSIV => {
		"A"		=> 1 ,
		"P"		=> 1
	} ,
	ACCOUNT_TYPE => {
		"630"	=> 1
	} ,
	O_ACCOUNT_TYPE => {
		"630"	=> 1
	} ,
);

my @bucketList = ();

# Get the list of attribute names (keys) from the bucket file header.
# -------------------------------------------------------------------
my $hdr = <>;
chomp $hdr;
my @attrNames = ( split /,/ , $hdr )[ $startAttrIdx .. $endAttrIdx ];

my @nonBlankableAttrs = qw ( EXCHANGE_ID SYMBOL_GROUP ACTIVE_PASSIVE TRADING_SESSION RT ACCOUNT_TYPE O_ACTIVE_PASSIV O_RT O_ACCOUNT_TYPE HIGH_LOW );
my %nonBlankableAttrMap = map { $_ => 1 } @nonBlankableAttrs;

# Build the buckets from the rest of the bucket file.
# ---------------------------------------------------
while ( <> ) {
	chomp;
	my $flds = CSV::parseRec ( $_ );
	my ( $bucketId , $bucketDesc , $bucketName ) = @$flds[ $bucketIdIdx , $bucketDescIdx , $bucketNameIdx ];
	next if !$bucketId;
	
	my %bucket = (
		"ID"	=> $bucketId ,
		"DESC"	=> $bucketDesc ,
		"NAME"	=> $bucketName ,
		"ATTRS"	=> {}
	);
		
	foreach my $idx ( $startAttrIdx .. $endAttrIdx ) {
		my $attrName = $attrNames[ $idx - $startAttrIdx ];
		foreach my $val ( split /,/ , $$flds[ $idx ] ) {
			addBucketAttr ( \%bucket , \%attrVals , $attrName , $val );
		}
	}
	
	push @bucketList , \%bucket;
}

# 'Blank' is a legal value for many of the bucket attributes.
# -----------------------------------------------------------
foreach my $attr ( @attrNames ) {
	if ( !exists $nonBlankableAttrMap{ $attr } ) {
		$attrVals{ $attr }{ '' } = 1;
	}
}

my %scenario = ();
if ( $scenarioFile ) {
	parseScenarioFile ( $scenarioFile , \%scenario , \%attrVals );
}
else {
	%scenario = map { $_ => "*" } @attrNames;
}

print join ( "," , @attrNames ) , ",Bucket ID,Bucket Name\n";
testScenarios ( \@bucketList , \%scenario , {} , \%attrVals , \@invalidScenarios , \@attrNames , 0 );