#!c:/perl/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;

use File::Basename;
use lib dirname $0;

use CSV;
use BillingScenario ( qw ( @invalidScenarios ) );

my $DEBUG;

sub dumpBucket {
	my ( $bucket , $attrNames ) = @_;
	return "[$$bucket{ ID } : $$bucket{ NAME }] ["
			. join ( "|" , 
				map { 
					my $attr = $_;
					if ( exists $$bucket{ ATTRS }{ $attr } ) {				
						join ( "," , 
							map { 
								my $val = $$bucket{ ATTRS }{ $attr }{ $_ };
								( $val == 0 ? "<>" : "" ) . "$_";
							} keys %{ $$bucket{ ATTRS }{ $attr } } 
						)
					}
					else {
						''
					} 
				} @$attrNames 
			)
			. "]";
}

sub addBucketAttr {
	my ( $bucket , $attrName , $val ) = @_;
	$val =~ s/ //g;
	return if $val eq '';
	my $yesno = ( $val =~ /^<>/ ? 0 : 1 );
	$val =~ s/^<>//g;
	$val =~ s/null/NULL/i;
	
	$$bucket{ "ATTRS" }{ $attrName }{ $val } = $yesno;
}

sub matchAttr {
	my ( $attrName , $attrVal , $bucketValMap ) = @_;
	
	print STDERR "MATCHING [$attrName=$attrVal] to [" , join ( " , " , map { "$_=$$bucketValMap{ $_ }" } keys %$bucketValMap ) , "]...\n" if $DEBUG;
	
	if ( $attrVal eq '' ) {	# --- a null attribute will fail unless there is a 'val => 0' bucket val ---
		foreach my $bucketAttr ( grep { $$bucketValMap{ $_ } == 0 } keys %$bucketValMap ) {
			return 1 if $bucketAttr ne 'NULL';
		}
		return 0;
	}
		
	if ( !exists $$bucketValMap{ $attrVal } ) {	# --- No such value for this attribute in bucket... ---
		if ( grep { /^0$/ } values %$bucketValMap ) {	# --- ...but attribute is 'NOT' some other value; pass it thru ---
			return 1;
		}
		else {	# --- otherwise, fail ---
			return 0;
		}
	}
	else {	# --- return whether this attribute/value is OK or not OK ---
		my $yesno = $$bucketValMap{ $attrVal };
		return $yesno;
	}
}

sub matchBucket {
	my ( $bucket , $trdFldMap , $attrNames ) = @_;
	print STDERR "Bucket " , dumpBucket ( $bucket , $attrNames ) , "\n" if $DEBUG;
	foreach my $trdFld ( keys %$trdFldMap ) {	
		next if !exists $$bucket{ ATTRS }{ $trdFld };
		
		my $trdVal = $$trdFldMap{ $trdFld };
		my $bucketValMap = $$bucket{ ATTRS }{ $trdFld };
		if ( !matchAttr ( $trdFld , $trdVal , $bucketValMap ) ) {
			print STDERR "...[$trdFld = $trdVal] didn't match...\n" if $DEBUG;
			return 0;
		}
	}
	print STDERR "...all attributes matched!\n" if $DEBUG;
	return 1;
}

sub dumpMatch {
	my ( $trdFldMap , $bucket ) = @_;
	print join ( "," , map { $$trdFldMap{ $_ } } sort keys %$trdFldMap );
	print ( $bucket ? ",$bucket->{ID},$bucket->{DESC}" : "NONE,NONE" ) , "\n";
	
}

sub testTrade {
	my ( $bucketList , $trdFldMap , $attrNames ) = @_;
	
	my $matchBucket;
	foreach my $bucket ( @$bucketList ) {
		if ( matchBucket ( $bucket , $trdFldMap , $attrNames ) ) {
			$matchBucket = $bucket;
			last;
		}
	}
	
#	Do something special for Iceberg trades - the hidden and displayed legs come in looking
#	exactly the same, both marked as HIDDEN.  For these orders, peek at the 'actual' bucket ID,
#	and if it differs from the calculated ID, tweak the trade to look like it's DISPLAYED and 
#	try again.
#	-------------------------------------------------------------------------------------------
	if ( $matchBucket && $$trdFldMap{ ICEBERG_HIDDEN } eq 'Y' ) {
		if ( $$trdFldMap{ PRODUCT_ID } ne $matchBucket->{ ID } ) {
			$$trdFldMap{ ICEBERG_DISPLAY } = 'Y' ; $$trdFldMap{ ICEBERG_HIDDEN } = 'N';
			foreach my $bucket ( @$bucketList ) {
				if ( matchBucket ( $bucket , $trdFldMap , $attrNames ) ) {
					$matchBucket = $bucket;
					last;
				}
			}
		}
	}
	
	return $matchBucket;
}		

my $bucketIdIdx = 1;
my $bucketDescIdx = 2;
my $bucketNameIdx = 3;
my $startAttrIdx = 4;
my $endAttrIdx = 39;

my $bucketFile;

GetOptions ( 
	'b=s'		=> \$bucketFile ,
	'd'			=> \$DEBUG
) or die;

if ( $bucketFile && ! -r $bucketFile ) {
	die "Cannot open billing bucket file [$bucketFile]\n";
}

my @bucketList = ();

# Get the list of attribute names (keys) from the bucket file header.
# -------------------------------------------------------------------
open ( BUCKET , $bucketFile ) or die "Cannot open billing bucket file [$bucketFile] : $!";

my $hdr = <BUCKET>;
chomp $hdr;
my @attrNames = map{ s/^\s*(.*?)\s*$/$1/ ; $_ }( split /,/ , $hdr )[ $startAttrIdx .. $endAttrIdx ];

my @nonBlankableAttrs = qw ( EXCHANGE_ID SYMBOL_GROUP ACTIVE_PASSIVE TRADING_SESSION RT ACCOUNT_TYPE O_ACTIVE_PASSIV O_RT O_ACCOUNT_TYPE HIGH_LOW );
my %nonBlankableAttrMap = map { $_ => 1 } @nonBlankableAttrs;

# Build the buckets from the rest of the bucket file.
# ---------------------------------------------------
while ( <BUCKET> ) {
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
			addBucketAttr ( \%bucket , $attrName , $val );
		}
	}
	
	push @bucketList , \%bucket;
}

close BUCKET;

# Now read the trades.
# --------------------
my $trdHdr = <>;
chomp ( $trdHdr );

my $i = 0;
my %trdFldNameMap = map { $_ => $i++ } split ( /,/ , $trdHdr );
my %revTrdFldNameMap = map { $trdFldNameMap{ $_ } => $_ } keys %trdFldNameMap;

print "$trdHdr,MY_BUCKET_ID,MY_BUCKET_DESC\n";

while ( <> ) {
	chomp;
	
	my $i = 0;
	my %trdFldMap = map { $revTrdFldNameMap{ $i++ } => $_ } split ( /,/ );
	
#	print STDERR "TRADE : " , Dumper ( \%trdFldMap ) , "\n";
	my $bucket = testTrade ( \@bucketList , \%trdFldMap , \@attrNames );
	print $_ , "," , ( $bucket ? "$bucket->{ID},$bucket->{DESC}" : "NONE,NONE" ) , "\n";
}