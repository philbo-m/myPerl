package AlphaTdrSaleSumm;

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
					keyFlds => [ 'PO' , 'Trader ID' , 'SYMBOL' , 'SUB-PRODUCT' ] ,
					ignoreFlds => [ 'MARKET' ]
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}

sub totalNetFee {
	my $self = shift;
	return $self->val ( {} , 'NET FEE' );
}

sub poNetFee {
	my $self = shift;
	my ( $po ) = @_;
	return $self->val ( { PO => $po } , 'NET FEE' );
}

sub symbolNetFee {
	my $self = shift;
	my ( $sym ) = @_;
	return $self->val ( { SYMBOL => $sym } , 'NET FEE' );
}

sub subProdNetFee {
	my $self = shift;
	my ( $product ) = @_;
	return $self->val ( { 'SUB-PRODUCT' => $product } , 'NET FEE' );
}

1;
