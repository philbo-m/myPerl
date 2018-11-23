package AccountSumm;

BEGIN {
	require CSVFile;
	push @ISA , 'CSVFile';
}

use strict;

sub new {
	my $class = shift;
	
	my $self = $class->SUPER::new ( 
					@_ , 
					keyFlds => [ 'ACCT_TYPE' , 'PRODUCT' ] ,
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

sub acctTypeBasicFee {
	my $self = shift;
	my ( $acctType ) = @_;
	return $self->val ( { ACCT_TYPE => $acctType } , 'BASIC_FEE' );
}

sub acctTypeNetFee {
	my $self = shift;
	my ( $acctType ) = @_;
	return $self->val ( { ACCT_TYPE => $acctType } , 'NET_FEE' );
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
	
	

		

