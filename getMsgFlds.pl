#!c:/perl/bin/perl

use strict;

use Getopt::Long;
use File::Basename;
use lib dirname $0;

use Data::Dumper;

use STAMPFld;

sub fmtTimeStamp {
	my ( $ts ) = @_;
	$ts =~ s/^(\d{8})(\d{2})(\d{2})(\d{2})(\d+)$/$1 $2:$3:$4.$5/;
	return $ts;
}

my ( @flds , @filters );
my $tabular = 1;
my $tsTranslate;

GetOptions ( 
	'f=s'	=> \@flds ,
	'p=s'	=> \@filters ,
	't'		=> \$tsTranslate
) or die;
$tabular = 0 if !@flds;

my ( @numFlds , $fldPtrn );
if ( $tabular ) {
	@numFlds = map { split /,/ } join ( "," , @flds );
	@numFlds = map { 
				exists ( $STAMPFld::revTagMap{ $_ } ) ? $STAMPFld::revTagMap{ $_ } : $_
			} @numFlds;
	$fldPtrn = join ( "|" , @numFlds );
}
else {
	$fldPtrn = "[0-9.]+";
}

# Filter syntax: tag=val|val|val,tag=val|val,...
# ----------------------------------------------
@filters = split /,/ , join ( ',' , @filters );

@filters = map { 
				my ( $key , $vals ) = split /=/;
				my $idx;
				( $key , $idx ) = split ( /\./ , $key );
				$idx = "\\.$idx" if $idx;
				$key = $STAMPFld::revTagMap{ $key } if exists $STAMPFld::revTagMap{ $key };
				$vals =~ s/\*/.*?/g;
				"\(^|[\\034\\036]\)${key}${idx}=\($vals\)\([\\034\\036]|\$\)";
			} @filters;

$fldPtrn = qr/[\034\036]+(${fldPtrn})=([[:print:]]+)/;
my $rePtrn = qr /[=\034\036]+/;

# Print header, if in tabular mode.
# ---------------------------------
if ( $tabular ) {
	print join ( "," , @flds ) , "\n";
}

while ( <> ) {
	print STDERR scalar(localtime(time())) , " $....\n" if ( !( $. % 1000000 ) );

	my $matchFilter = 1;
	foreach my $filter ( @filters ) {
		if  ( ! /$filter/ ) {
			$matchFilter = 0;
			last;
		}
	}
	next if !$matchFilter;

	s/.//;
	
	if ( $tabular ) {
		my %fldMap = ( m/${fldPtrn}/g );
		print join ( "," , map { $fldMap{ $_ } } @numFlds ) , "\n";
	}
	else {
		my @fldList = split /$rePtrn/;
		for ( my $i = 0 ; $i < $#fldList ; $i += 2 ) {
			my $key = $fldList[ $i ];
			my $val = $fldList[ $i + 1 ];
			if ( $tsTranslate && ( $key == 56 || $key == 57 ) ) {
				$val = fmtTimeStamp ( $val );
			}
			print "[$key]$STAMPFld::tagMap{ $key } = $val\n";
		}
		print "\n";
	}
}
	