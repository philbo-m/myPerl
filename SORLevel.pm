package SORLevel;

sub new {
	my $class = shift;
	my $self = {
		price		=> undef ,
		qty			=> undef ,
		@_
	};

	$self->{tradeByID} = {};
	$self->{cacheCxlIdMap} = {};
	
	return bless $self;
}

sub addTrade {
	my $self = shift;
	my ( $tradeID , $qty ) = @_;

	$self->{tradeByID}{ $tradeID } = {
								qty		=> $qty
							};
	$self->{qty} += $qty;
}

sub deleteTrade {
	my $self = shift;
	my ( $tradeID ) = @_;
	
	my $trade = delete $self->{tradeByID}{ $tradeID };
	if ( !$trade ) {
		print STDERR "WARNING : deleting nonexistent trade [$tradeID].\n";
	}
	else {
		$self->{qty} -= $trade->{qty};
	}
}

1;		