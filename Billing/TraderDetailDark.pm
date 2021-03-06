package TraderDetailDark;

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
					keyFlds => [ 'TRADER_ID' , 'SYMBOL' , 'PRODUCT' ] ,
					ignoreFlds => [ 'MARKET' ]
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

sub symbolBasicFee {
	my $self = shift;
	my ( $sym ) = @_;
	return $self->val ( { SYMBOL => $sym } , 'BASIC_FEE' );
}

sub symbolNetFee {
	my $self = shift;
	my ( $sym ) = @_;
	return $self->val ( { SYMBOL => $sym } , 'NET_FEE' );
}

sub subProdBasicFee {
	my $self = shift;
	my ( $product ) = @_;
	return $self->val ( { PRODUCT => $product } , 'BASIC_FEE' );
}

sub subProdNetFee {
	my $self = shift;
	my ( $product ) = @_;
	return $self->val ( { PRODUCT => $product } , 'NET_FEE' );
}


1;
	
	

		

