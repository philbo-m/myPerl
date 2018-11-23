#!c:/perl/bin/perl

use strict;

use Getopt::Long;
use File::Basename;
use lib dirname $0;

use STAMPFld;

sub match {
	my ( $buf , $ptrns , $excludePtrns ) = @_;
	my $isMatch = 1;

	foreach my $ptrn ( @$ptrns ) {
		if ( !grep { /$ptrn/ } $buf ) {
			$isMatch = 0;
			last;
		}
	}
	
	if ( $isMatch ) {
		foreach my $ptrn ( @$excludePtrns ) {
			if ( grep { /$ptrn/ } @$buf ) {
				$isMatch = 0;
				last;
			}
		}
	}
	
	return $isMatch;
}

sub filter {
	my ( $buf , $flds , $fldPtrn , $busCont , $fldSep , $raw ) = @_;
	my @buf = ( split /[${busCont}${fldSep}]+/ , $buf );
	
	shift @buf;
	if ( $fldPtrn ) {
		my %fldMap = map { my ( $n ) = /^([\d\.]+)=/ ; $n => $_ } grep ( /$fldPtrn/ , @buf );
		@buf = ();
		foreach my $fld ( @$flds ) {
			push @buf , $fldMap{ $fld };
		}
	}

	if ( $raw ) {
		return join ( "," , map { s/^.*?=// ; $_ } @buf );
	}
	else {
		return join ( "\n" , map {
								my ( $key , $val ) = split /=/;
								"[$key]$STAMPFld::tagMap{ $key } = $val"
							} @buf
					);
	}
}

my ( $transportHdr , $ctrlHdr , $busCont , $ctrlTrlr , $transportTrlr , $fldSep ) 
	= ( chr ( 0x02 ) , chr ( 0x01 ) , chr ( 0x1c ) , chr ( 0x1d ) , chr ( 0x03 ) , chr ( 0x1e ) );

local $/ = ${ctrlHdr};

my ( @ptrns , @excludePtrns , @flds , $raw );

GetOptions ( 
	'p=s'	=> \@ptrns ,
	'x=s'	=> \@excludePtrns ,
	'f=s'	=> \@flds ,
	'r'		=> \$raw
) or die;
die "Specify at least one pattern with the '-p' option." if !@ptrns;

@ptrns = map { split /,/ } join ( "," , @ptrns );
@excludePtrns = map { split /,/ } join ( "," , @excludePtrns );
@flds = map { split /,/ } join ( "," , @flds );

my $fldPtrn;
if ( scalar @flds ) {
	$fldPtrn = "^(" . join ( "|" , @flds ) . ")=";
}

# Print header, if in raw (tabular) mode.
# ---------------------------------------
if ( $raw && scalar @flds ) {
	print join ( "," , map { 
							my ( $key , $idx ) = split /\./;
							$STAMPFld::tagMap{ $key } . ( $idx ? ".$idx" : "" )
						} @flds
					) , "\n";
}

while ( <> ) {
	chomp;
	s/${transportTrlr}.*$//s;
	next if !match ( $_ , \@ptrns , \@excludePtrns );
	print filter ( $_ , \@flds , $fldPtrn , $busCont , $fldSep , $raw ) , "\n" , ( $raw ? "" : "\n" );
}

		
		
	
	