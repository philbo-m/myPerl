#!c:/perl/bin/perl

use strict;
use Getopt::Long;

sub usageAndExit {
	print STDERR "Usage: gpFIX.pl -p ptrn[,ptrn...] [-x excludePtrn[,excludePtrn...]] [-f fldID[,fldID...]] [-s separator]\n";
	exit 1;
}

sub match {
	my ( $buf , $ptrns , $excludePtrns ) = @_;
	my $isMatch = 1;

	print "BUF [$buf]\n";
	foreach my $ptrn ( @$ptrns ) {
		print "...Looking for [$ptrn]\n";
		if ( !grep { /$ptrn/ } @$buf ) {
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
	my ( $buf , $flds , $fldPtrn , $fldSep , $raw ) = @_;
	if ( !$fldPtrn ) {
		return join ( "\n" , @$buf );
	}
	else {
		my %fldMap = map { my ( $n ) = /\[([\d\.]+)\]/ ; $n => $_ } grep ( /$fldPtrn/ , @$buf );
		my @outFlds;
		foreach my $fld ( @$flds ) {
			$fld = "" if $fld eq 'h';
			push @outFlds , $fldMap{ $fld };
		}
		if ( $raw ) {
			map { s/^.* = // } @outFlds;
		}
		return join ( $fldSep , @outFlds );
	}
}	

my ( @ptrns , @excludePtrns , @flds );
my $fldSep = "\n";
my $raw;

GetOptions ( 
	'p=s'	=> \@ptrns ,
	'x=s'	=> \@excludePtrns ,
	'f=s'	=> \@flds ,
	's=s'	=> \$fldSep ,
	'r'		=> \$raw
) or usageAndExit;
die "Specify at least one pattern with the '-p' option." if !@ptrns;

@ptrns = map { split /,/ } join ( "," , @ptrns );
@excludePtrns = map { split /,/ } join ( "," , @excludePtrns );
@flds = map { split /,/ } join ( "," , @flds );

my $fldPtrn;
if ( scalar @flds ) {
	$fldPtrn = "^\\[(" . join ( "|" , @flds ) . ")\\]";
	if ( grep ( /h/ , @flds ) ) {
		$fldPtrn = "(\\d{2}:\\d{2}:\\d{2}\\.\\d{3,6} :|$fldPtrn)";
	}
}

my @msgBuf = ();

while ( <> ) {
	chomp;
	if ( $_ eq "" ) {
		if ( match ( \@msgBuf , \@ptrns , \@excludePtrns ) ) {
			print filter ( \@msgBuf , \@flds , $fldPtrn , $fldSep , $raw ) , "\n" , ( $fldSep eq "\n" ? "\n" : "" );
		}
		@msgBuf = ();
		next;
	}
	push @msgBuf , $_;
}

if ( match ( \@msgBuf , \@ptrns , \@excludePtrns ) ) {
	print filter ( \@msgBuf , \@flds , $fldPtrn , $fldSep , $raw ) , "\n" , ( $fldSep eq "\n" ? "\n" : "" );
}