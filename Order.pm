package Order;

sub new {
	my $class = shift;
	my $self = {
		Quantity	=> undef ,
		Price		=> undef ,
		@_
	};

	$self->{RemQty} = $self->{Quantity};
	$self->{Fills} = [];
	$self->{FillsByPrice} = {};
	
	return bless $self;
}

sub applyCFO {
	my $self = shift;
	my ( $cfo ) = @_;
	
	$self->{Quantity} = $cfo->{Quantity};
	$self->{TotalQuantity} = $cfo->{TotalQuantity};
	$self->{Price} = $cfo->{Price};
	
	return $self;
}

sub applyTrade {
	my $self = shift;
	my ( $qty , $remQty , $price ) = @_;
	
	push @{ $self->{Fills} } , { Qty => $qty , Qrice => $price };
	$self->{RemQty} -= $qty;
}

sub clone {
	my $self = shift;

	my $that = new Order ( %$self );	
	return $that;
}

sub dump {
	my $self = shift;

	return "$self->{Side} $self->{RemQty} $self->{Symbol} $self->{Price} [$self->{Undisplayed}] [$self->{LongLife}] $self->{PO} $self->{TrdrID} $self->{ClOrdID} $self->{OrigClOrdID}";
}

1;