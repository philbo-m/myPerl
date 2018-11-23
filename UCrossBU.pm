package UCrossBU;

use strict;
use Data::Dumper;

require Exporter;
our @ISA = qw ( Exporter );
our @EXPORT = qw ( %subProdMap %revSubProdMap %BUMaster parseBUFile );

our %subProdMap = (
	"TSX HIGH CLOB"	=> [ qw ( T_HI_CLOB T_HI_CLOB_ETF T_HI_CLOB_ETF_JIT T_HI_CLOB_ETF_JIT_LL T_HI_CLOB_ETF_LL T_HI_CLOB_INTL 
								T_HI_CLOB_INTL_LL T_HI_CLOB_JIT T_HI_CLOB_JIT_INTL T_HI_CLOB_JIT_INTL_LL T_HI_CLOB_JIT_LL 
								T_HI_CLOB_LL T_HI_DARK_LIT T_HI_DARK_LIT_ETF T_HI_DARK_LIT_INTL
							)
						]
);

our %revSubProdMap = ();
foreach my $prodKey ( keys %subProdMap ) {
	foreach my $subProd ( @{ $subProdMap{ $prodKey } } ) {
		$revSubProdMap{ $subProd } = $prodKey;
	}
}

our %BUMaster = (	# --- sample data ---
	7	=> {
		BUMap		=> {
							Alpha	=> [ qw ( TD721OM TD917FI TD251IT TD911FI ) ] ,
							Beta	=> [ qw ( TD722OM TD899FI TD786IR TD898FI ) ] ,
							Gamma	=> [ qw ( TD001NX TD909FI TD201IT TD001UK ) ] ,
							Delta	=> [ qw ( TD744IT TD593IT TD908FI TD036IR ) ]
						} ,
		FeeMap		=> {
							T_HI_CLOB	=> {
								BaseRates	=> [ .0004 , .0000 ] ,
								Alpha	=> {
									Beta	=> [ .0003 , .0001 ] ,
									Gamma	=> [ .0005 , -.0001 ] ,
									Delta	=> [ .0010 , -.0006 ]
								} ,
								Beta	=> {
									Delta	=> [ .0007 , -.0003 ]
								}
							}
						}
	}
);

foreach my $po ( keys %BUMaster ) {
	foreach my $bu ( keys %{ $BUMaster{ $po }{ BUMap } } ) {
		foreach my $trdrID ( @{ $BUMaster{ $po }{ BUMap }{ $bu } } ) {
		
#			Should check here for doubly-assigned TrdrIDs
#			---------------------------------------------
			$BUMaster{ $po }{ RevBUMap }{ $trdrID } = $bu;
		}
	}
}

# ------------------------------------------------------------------------
# Disgusting and highly breakable method for parsing a BU assignment file.
# ------------------------------------------------------------------------
sub parseBUFile {
	my ( $file , $subProdMap , $BUMap ) = @_;
	if ( !open FILE , $file ) {
		print STDERR "ERROR : cannot open BU file [$file] : $!\n";
		return;
	}

	my $POMap = {};
	
#	Find the PO.
#	------------
	my $po;
	while ( <FILE> ) {
		chomp;
		my @rec = split /,/;
		if ( $rec[ 0 ] eq 'PO' ) {
			$po = $rec[ 1 ];
			last;
		}
	}
	if ( !$po ) {
		print STDERR "ERROR : PO not found in BU file [$file].\n";
		close FILE;
		return;
	}
	elsif ( exists $BUMap->{$po} ) {
		print STDERR "ERROR : PO [$po] already defined in BU file [$file].\n";
		close FILE;
		return;
	}
	
# 	Find the Product.
#	-----------------
	my $prod;
	while ( <FILE> ) {
		chomp;
		my @rec = split /,/;
		if ( $rec[ 0 ] eq 'Product' ) {
			$prod = $rec[ 1 ];
			last;
		}
	}
	if ( !$prod ) {
		print STDERR "ERROR : No products found in BU file [$file].\n";
		close FILE;
		return;
	}
	elsif ( !exists $subProdMap->{$prod} ) {
		print STDERR "ERROR : Unknown product [$prod] in BU file [$file].\n";
		close FILE;
		return;
	}
	elsif ( exists $POMap->{$prod} ) {
		print STDERR "ERROR : Product [$prod] already defined for PO [$po] in BU file [$file].\n";
		close FILE;
		return;
	}
		
#	Get the default rate.
#	---------------------
	my @defRates;
	while ( <FILE> ) {
		chomp;
		if ( /^,*Default[^,]*,([^,]+),([^,]+),/ ) {
			@defRates = ( $1 , $2 );
			map { s/\$// } @defRates;
			last;
		}
	}
	if ( !@defRates ) {
		print STDERR "ERROR : Default rates not found in BU file [$file].\n";
		close FILE;
		return;
	}
	
	$POMap->{FeeMap}->{$prod}->{BaseRates} = \@defRates;
	my $defSpread = $defRates[ 0 ] + $defRates[ 1 ];

#	Get the BU mappings.
#	--------------------
	while ( <FILE> ) {
		chomp;
		last if /^,*Passive,*$/i;
	}
	$_ = <FILE>;	# --- should contain 'Contra' followed by a list of BUs ---
	chomp;
	s/^,*Contra,+//i;
	
	my @contraBUs = split ( /,+/ );
	my %contraBUMap = map { $_ => 1 } @contraBUs;
	
	foreach my $contraBU ( @contraBUs ) {
		next if $contraBU =~ /^\s*$/;
		if ( exists $POMap->{ BUMap }{ $contraBU } ) {
			print STDERR "ERROR : duplicate BU [$contraBU] in BU file [$file].\n";
			close FILE;
			return;
		}
		$POMap->{ BUMap }{ $contraBU } = [];
	}
	<FILE>;		# --- skip the matrix header ---
	
	
	while ( <FILE> ) {
		chomp;
		last if ( /^,*$/ );
		s/\$//g;
		my ( $BU , $rates ) = /^[^,]*,([^,]+),(.*)$/;
		if ( !delete $contraBUMap{ $BU } ) {
			print STDERR "ERROR : inconsistent BU [$BU] in BU file [$file] mapping matrix.\n";
			close FILE;
			return;
		}
		my @rates = split /,/ , $rates;
		for ( my $idx = 0 ; $idx < scalar @rates ; $idx += 2 ) {
			my ( $actRate , $psvRate ) = ( $rates[ $idx ] , $rates[ $idx + 1 ] );
			my $contraBU = $contraBUs[ $idx / 2 ];
			if ( $actRate ne '' && $psvRate ne '' ) {
				my $spread = $actRate + $psvRate;
				if ( abs ( $spread - $defSpread ) > 0.00001 ) {
					print STDERR "ERROR: incorrect spread [$spread] for [$BU] -> [$contraBU] in BU file [$file] mapping matrix [" , $defSpread - $spread , "].\n";
					close FILE; 
					return;
				}
				$POMap->{ FeeMap }{ $prod }{ $BU }{ $contraBU } = [ $actRate , $psvRate ];
			}
		}
	}
	if ( scalar keys %contraBUMap ) {
		print STDERR "ERROR : inconsistent BU(s) [" , join ( " , " , keys %contraBUMap ) , "] in BU file [$file] mapping matrix.\n";
		close FILE;
		return;
	}

#	Get the TraderID BU assignments.
#	--------------------------------
	while ( <FILE> ) {
		last if /^TraderID,BU/i;
	}
	
	while ( <FILE> ) {
		chomp;
		my ( $trdrID , $BU ) = split /,/;
		last if !$trdrID;
		
		if ( !exists $POMap->{ BUMap }{ $BU } ) {
			print STDERR "ERROR : TraderID [$trdrID] assigned to unknown BU [$BU] in BU file [$file].\n";
			close FILE;
			return;
		}
	
		if ( exists  $POMap->{ RevBUMap }{ $trdrID } ) {
			print STDERR "ERROR : TraderID [$trdrID] doubly assigned in BU file [$file].\n";
			close FILE;
			return;
		}
		$POMap->{ RevBUMap }{ $trdrID } = $BU;

		push @{ $POMap->{ BUMap }{ $BU } } , $trdrID;
	}
		
	close FILE;
	
	$BUMap->{$po} = $POMap;
	return;
}
	
1;	