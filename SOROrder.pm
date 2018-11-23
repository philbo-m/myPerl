package SOROrder;

use SORLevel;

sub new {
	my $class = shift;
	my $self = {
		side		=> undef ,
		vol			=> undef ,
		price		=> undef ,
		@_
	};

	$self->{lvls} = [];
	$self->{lvlByPrice} = {};
	$self->{lvlByTradeID} = {};
	$self->{cacheCxlIDMap} = {};

	
	return bless $self;
}

sub addTrade {
	my $self = shift;
	my ( $tradeID , $qty , $price ) = @_;
	
	if ( $price == 0 ) {
	
#		Trade Cancel.  Look up and cancel the original trade.
#		-----------------------------------------------------
		my $lvl = $self->{lvlByTradeID}{ $tradeID };
		if ( $lvl ) {	# --- original trade found ---
			print STDERR "[$self] CXLing trade [$tradeID]\n";
			$lvl->deleteTrade ( $tradeID );
		}
		else {	# --- original trade NOT found - save tradeID for future ref ---
			$self->{cacheCxlIDMap}{ $tradeID } = 1;
			print STDERR "[$self] Caching CXLed trade [$tradeID] for future suppression\n";
		}
	}
	else {
		my $trdCxled = $self->{cacheCxlIDMap}{ $tradeID };
		if ( $trdCxled ) {
			print STDERR "[$self] Suppressing addition of CXLed trade [$tradeID]\n";
		}
		else {
			my $lvl = $self->{lvlByPrice}{ $price };
			if ( !$lvl ) {
				$lvl = new SORLevel (
								price => $price ,
								qty => 0
							);
				$self->{lvlByPrice}{ $price } = $lvl;
				push @{ $self->{lvls} } , $lvl;
			}
#			print STDERR "[$self] Adding trade [$tradeID] [$qty] [$price]\n";
			$lvl->addTrade ( $tradeID , $qty );
			$self->{lvlByTradeID}{ $tradeID } = $lvl;
		}
	}
}

sub getLvls {
	my $self = shift;
	
	my @xxx = sort { 
			$self->{side} eq "SELL" ? 
				$b->{price} <=> $a->{price} : 
				$a->{price} <=> $b->{price} 
		} grep { $_->{qty} > 0 } @{ $self->{lvls} };
	return @xxx;
}	
	
1;
