#!c:/perl/bin/perl

sub randomize {
	my ( $str ) = @_;
	my $rnd;
	my $len = length ( $str );
	$len = 3 if $len < 3;
	$rnd .= [ a..z , A..Z ]->[ rand 52 ] for 1 .. $len;
	return $rnd;
}

my %obMap = (
	"70"		=> { '1' => '1' } ,		# --- BrokerNumber ---
	"181"		=> { '1' => '1' } ,		# --- PrivateBrokerNumber ---
	"62"		=> {} ,					# --- UserId ---
	"265"		=> {} ,					# --- Exchange-UserId ---
	"75"		=> {} ,					# --- ActionSource ---
	"311"		=> {} ,					# --- GatewayId ---
	"1"			=> {} ,					# --- AccountId ---
	"7"			=> {} ,					# --- BuyAccountId ---
	"45"		=> {} ,					# --- SellAccountId ---
	"81"		=> {} ,					# --- UserOrderId ---
	"199"		=> {} ,					# --- SpecialistName ---
	"312"		=> {} ,					# --- SpecialistPhoneNumber ---
	"587"		=> {} ,					# --- NoTradeKey ---
	"511"		=> {} ,					# --- SOROrderID1 ---
	"512"		=> {} ,					# --- SOROrderID2 ---
	"192"		=> {} ,					# --- OrderKey ---
);
my $obMapPtrn = "(([^0-9.])(" . join ( "|" , keys %obMap ) . ")(\\.[01])?=([[:print:]]+))";

print STDERR "$obMapPtrn\n";

srand;

while ( <> ) {
	chomp;
	s/$obMapPtrn/ {
#					print STDERR "[$1] [$2] [$3] [$4] [$5]\n";
					my $obVal = $obMap{ $3 }{ $5 };
#					print STDERR "[$3] [$5] [$obVal]...\n";
					if ( !$obVal ) {
						$obVal = randomize ( $5 );
						$obMap{ $3 }{ $5 } = $obVal;
					}
					"${2}${3}${4}=$obVal"
				}
			/gex;
	print "$_\n";
}	