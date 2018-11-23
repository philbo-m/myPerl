package TraderProductDetail;

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
					keyFlds => [ 'TRADER_ID' , 'PRODUCT' ]
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}

sub totalBasicFee {
	my $self = shift;
	return $self->val ( {} , 'BASIC FEE' );
}

sub totalNetFee {
	my $self = shift;
	return $self->val ( {} , 'NET_FEE' );
}

sub traderBasicFee {
	my $self = shift;
	my ( $trdrID ) = @_;
	return $self->val ( { TRADER_ID => $trdrID } , 'BASIC FEE' );
}

sub traderNetFee {
	my $self = shift;
	my ( $trdrID ) = @_;
	return $self->val ( { TRADER_ID => $trdrID } , 'NET_FEE' );
}

sub subProdBasicFee {
	my $self = shift;
	my ( $product ) = @_;
	return $self->val ( { PRODUCT => $product } , 'BASIC FEE' );
}

sub subProdNetFee {
	my $self = shift;
	my ( $product ) = @_;
	return $self->val ( { PRODUCT => $product } , 'NET_FEE' );
}

1;
