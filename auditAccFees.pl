#!c:/perl/bin/perl

use strict;

my %feePtrns = (
	'T_HI_ELP'						=> 'T_HI_ELP(_ETF)?' ,
	'T_HI_CLOB(_(ICE|JIT))?'		=> 'T_HI_CLOB(_ETF)?(_(ICE|JIT))?' ,
	'T_HI_DARK_LIT'					=> 'T_HI_DARK_LIT(_ETF)?' ,
	'T_LO_CLOB'						=> 'T_LO_CLOB_T[12]_REG' ,
	'T_LO_CLOB_(ICE|JIT)?'			=> 'T_LO_CLOB_(ICE|JITNEY)_T[12]' ,
	'T_LO_(DARK|LIT)_(LIT|DARK)'	=> 'T_LO_(DARK|LIT)_(LIT|DARK)_T[12]' ,
	'T_(HI|LO)(_ETF)?_RT'			=> 'T_(HI|LO)(_ETF)?_RT' ,
	'V_LO_CLOB'						=> 'V_LO_CLOB_T[12]_REG' ,
	'V_LO_CLOB_(ICE|JIT)'			=> 'V_LO_CLOB_(ICE|JIT)_T[12]' ,
	'V_LO_DEBT(_(ICE|JIT))?'		=> 'V_LO_CLOB(_(ICE|JIT))?_T[12]' ,
	'V_LO_(DARK|LIT)_(LIT|DARK)'	=> 'V_LO_(DARK|LIT)_(LIT|DARK)_T[12]' ,
	'V_(HI|LO)_VOD'					=> 'V_(HI|LO)_VOD'
);

my $spFldIdx = $ARGV[ 0 ];
die "Must specify SubProduct fld idx (zero based)." if !$spFldIdx;
shift;

while ( <> ) {
	chomp ; s/"//g;
	my $spFld = ( split /,/ )[ $spFldIdx ];
	my $match = 0;
	foreach my $ptrn ( keys %feePtrns ) {
		foreach ( $ptrn , $feePtrns{ $ptrn } ) {
#			print "Matching [$spFld] vs [$_]\n";
			if ( $spFld =~ /^$_$/ ) {
#				print "[$spFld] matches [$_]\n";
				$match = 1;
				last;
			}
			last if $match;
		}
	}
	print "$_\n" if ( !$match );
}