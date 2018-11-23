#!c:/perl/bin/perl

use strict;
use Getopt::Long;

use File::Basename;
use lib dirname $0;
use Data::Dumper;

use FIXMsg;

my $delim = "";
# $delim = '\|';
my ( @showTags , %showTags , @filters , $injectAcct , $simple , $showUniqId , $tabular );

my %acctIdByClOrdId = ();

GetOptions ( 
	'd=s'	=> \$delim ,
	't=s'	=> \@showTags ,
	'f=s'	=> \@filters ,
	'a'		=> \$injectAcct ,
	's'		=> \$simple ,
	'r'		=> \$tabular ,
	'u'		=> \$showUniqId
) or die;
@showTags = split ( /,/ , join ( ',' , @showTags ) );
%showTags = map { $_ => 1 } split ( /,/ , join ( ',' , @showTags ) );

# Filter syntax: tag=val|val|val,tag=val|val,...
# ----------------------------------------------
@filters = split /,/ , join ( ',' , @filters );

@filters = map { 
				my ( $key , $vals ) = split /=/;
				$vals =~ s/\*/.*?/g;
				"\(^|$delim\)$key=\($vals\)\($delim|\$\)";
			} @filters;

if ( $simple ) {
	$/ = undef;
	my $msgBuf = <>;
	foreach ( split /\n\n/ , $msgBuf ) {
		my $msg = new FIXMsg ( 
						delim		=> $delim ,
						simple		=> $simple ,
						showTags	=> \@showTags
					);
		$msg->parseSimple ( $_ );
		print $msg->dump ( $showUniqId ), "\n\n";
	}
}

elsif ( $delim ) {

	if ( $tabular ) {
		print "Timestamp," , join ( "," , @showTags ) , "\n";
	}
	
	while ( <> ) {
		chomp;
		if ( !( $. % 100000 ) ) {
			print STDERR $. , "...\n";
		}
		next if /^\s*$/;

		my $matchFilter = 1;
		foreach my $filter ( @filters ) {
			if  ( ! /$filter/ ) {
				$matchFilter = 0;
				last;
			}
		}
		next if !$matchFilter;
		
		my $msg = new FIXMsg ( 
						delim		=> $delim ,
						simple		=> $simple ,
						showTags	=> \@showTags
					);
		$msg->parse ( $_ );
		
#		Hack to inject an Account into the msg, if it isn't already there
#		-----------------------------------------------------------------
		if ( $injectAcct ) {
			my $acctId = $msg->fldVal ( 1 );
			if ( !$acctId ) {
				my $origClOrdId = $msg->fldVal ( 41 );
				if ( $origClOrdId ) {
					$acctId = $acctIdByClOrdId{ $origClOrdId };
					if ( $acctId ) {
						$msg->addFld ( "1=$acctId" );
					}
				}
			}
			if ( $acctId ) {
				$acctIdByClOrdId{ $msg->fldVal ( 11 ) } = $acctId;
			}
		}

		print $msg->dump ( $showUniqId , $tabular ) , "\n";
		
		$msg->init;
	}
}