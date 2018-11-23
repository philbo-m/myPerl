package TraderAccount;

BEGIN {
	require CSVFile;
	push @ISA , 'CSVFile';
}

use strict;

sub new {
	my $class = shift;

	my $self = $class->SUPER::new ( 
					file	=> undef ,
					@_ , 
					keyFlds => [ 'TRADER_ID' ]
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}

sub totalBasicFee {
	my $self = shift;
	return $self->val ( {} , 'BASIC_FEE' );
}

sub totalNetFee {
	my $self = shift;
	return $self->val ( {} , 'NET_FEE' );
}

sub traderBasicFee {
	my $self = shift;
	my ( $trdrID ) = @_;
	return $self->val ( { TRADER_ID => $trdrID } , 'BASIC_FEE' );
}

sub traderNetFee {
	my $self = shift;
	my ( $trdrID ) = @_;
	return $self->val ( { TRADER_ID => $trdrID } , 'NET_FEE' );
}

sub acctTypeFee {
	my $self = shift;
	my ( $acctType ) = @_;
	return $self->val ( {} , $acctType );
}

1;
