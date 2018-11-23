#!c:/perl/bin/perl

use strict;

use File::Basename;
use lib dirname $0;

my @ignoreFlds = qw ( ISDELETED MASTERRECORDID PARENTID OWNERID CREATEDDATE CREATEDBYID LASTMODIFIEDDATE LASTMODIFIEDBYID SYSTEMMODSTAMP LASTACTIVITYDATE LASTVIEWEDDATE LASTREFERENCEDDATE JIGSAWCOMPANYID LASTCUREQUESTDATE LASTCUUPDATEDATE JIGSAWCONTACTID REPORTSTOID EMAILBOUNCEDREASON EMAILBOUNCEDDATE );
my %ignoreFlds = map { $_ => 1 } @ignoreFlds;

sub parseHdr {
	my ( $hdrRec , $src , $fldByIdx ) = @_;
	
	my $idx = 0;
	foreach my $fld ( split /,/ , $hdrRec ) {
		$$fldByIdx{ $src }{ $idx++ } = $fld;
	}
}

sub addRec {
	my ( $flds , $recMap , $src , $fldIdxByName , $sharedFldNames ) = @_;

	my $acctId = $$flds[ $$fldIdxByName{ $src }{ 'ACCOUNTID' } ];
	my $lastName = $$flds[ $$fldIdxByName{ $src }{ 'LASTNAME' } ];
	my $firstName = $$flds[ $$fldIdxByName{ $src }{ 'FIRSTNAME' } ];

	print STDERR "Adding [$acctId] [$lastName] [$firstName] [$src] [" , join ( " , " , @$flds ) , "]\n";
	my @sharedFlds = ();
	foreach my $fldName ( @$sharedFldNames ) {
		push @sharedFlds , $$flds[ $$fldIdxByName{ $src }{ $fldName } ];
	}
	if ( exists $$recMap{ $acctId }{ $lastName }{ $firstName }{ $src } ) {
		print STDERR "DUPLICATE ENTRY [$acctId] [$lastName] [$firstName] [$src]\n";
	}
	$$recMap{ $acctId }{ $lastName }{ $firstName }{ $src } = \@sharedFlds;
}

my $tmxAcctCSV = $ARGV[ 0 ];
my $alphaCSV = $ARGV[ 1 ];
my $tmxCSV = $ARGV[ 2 ];

# Make an AccountId -> AcctName map.
# ----------------------------------
my %acctNameById = ();
my %acctSrcById = ();

open ACCT , $tmxAcctCSV;
while ( <ACCT> ) {
	chomp ; s/"//g;
	my ( $acctId , $src , $acctName ) = split /,/;
	$acctSrcById{ $acctId } = $src ;
	$acctNameById{ $acctId } = $acctName;
#	print "ACCT ID [$acctId] NAME [$acctName]\n";
}
close ACCT;

open TMX , $tmxCSV;
open ALPHA , $alphaCSV;

# Grab headers and determine shared fields.
# -----------------------------------------
my %fldNameMap = ();
my $hdrRec = <TMX>;
chomp $hdrRec;
parseHdr ( $hdrRec , 'TMX' , \%fldNameMap );

$hdrRec = <ALPHA>;
chomp $hdrRec;
parseHdr ( $hdrRec , 'ALPHA' , \%fldNameMap );

my %revFldNameMap = ();
foreach my $src ( keys %fldNameMap ) {
	foreach my $idx ( sort { $a <=> $b } keys %{ $fldNameMap{ $src } } ) {
#		print "[$src] [$idx] [$fldNameMap{ $src }{ $idx }]\n";
		$revFldNameMap{ $src }{ $fldNameMap{ $src }{ $idx } } = $idx;
	}
}

my @sharedFldNames = ();
foreach my $idx ( sort { $a <=> $b } keys %{ $fldNameMap{ 'TMX' } } ) {
	my $fldName = $fldNameMap{ 'TMX' }{ $idx };
	if ( $revFldNameMap{ 'ALPHA' }{ $fldName } && !$ignoreFlds{ $fldName } ) {
		push @sharedFldNames , $fldName;
	}
}

# Grab the remaining records.
# ---------------------------
my %recMap = ();

while ( <TMX> ) {
	chomp;
	my @flds = split /,/;
	
	addRec ( \@flds , \%recMap , 'TMX' , \%revFldNameMap , \@sharedFldNames );
}

while ( <ALPHA> ) {
	chomp;
	my @flds = split /,/;

#	Use the cached Account Name.
#	----------------------------
	my $acctId = $flds[ $revFldNameMap{ 'ALPHA' }{ 'ACCOUNTID' } ];
#	print "AcctId [$acctId] ALPHA [$flds[ $revFldNameMap{ 'ALPHA' }{ 'ACCOUNT_NAME' } ]] TMX [$acctNameById{ $acctId }]\n";
	$flds[ $revFldNameMap{ 'ALPHA' }{ 'ACCOUNT_NAME' } ] = $acctNameById{ $acctId };

	addRec ( \@flds , \%recMap , 'ALPHA' , \%revFldNameMap , \@sharedFldNames );
}	

close ALPHA;
close TMX;

print "SOURCE,ACTION," , join ( "," , @sharedFldNames ) , "\n";
foreach my $acctId ( sort { $acctNameById{ $a } cmp $acctNameById{ $b } } keys %recMap ) {
	print STDERR "[$acctId]\n";
	next if ( $acctId eq 'OMIT' );
	my $action = ( $acctSrcById{ $acctId } eq 'ALPHA' ? 'I' : '' );
	foreach my $lastName ( sort keys %{ $recMap{ $acctId } } ) {
		print STDERR "...[$lastName]\n";
		foreach my $firstName ( sort keys %{ $recMap{ $acctId }{ $lastName } } ) {
			print STDERR "......[$firstName]\n";
			foreach my $src ( 'TMX' , 'ALPHA' ) {
				print STDERR ".........[$src]\n";
				my $rec = $recMap{ $acctId }{ $lastName }{ $firstName }{ $src };
				if ( $rec ) {
					print "$src,$action," , join ( "," , @$rec ) , "\n";
				}
			}
		}
	}
}
	
