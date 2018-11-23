package STAMPOrder;

sub new {
	my $class = shift;
	
	my $self = {
		cfoCount	=> 0 ,
		side		=> undef ,
		volume		=> 0 ,
		price		=> 0 ,
		timeStamp	=> undef ,
		exchange	=> undef ,
		trdrID		=> undef ,
		@_
	};
	
	$self->{remVol} = $self->{volume};

	return bless $self;
}

1;
