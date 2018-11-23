package MktSaleSumm;

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
					keyFlds => [ 'PO' , 'SUB-PRODUCT' ] ,
					ignoreFlds => [ 'MARKET ID' ]
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
	return $self->val ( {} , 'NET FEE' );
}

sub poBasicFee {
	my $self = shift;
	my ( $po ) = @_;
	return $self->val ( { PO => $po } , 'BASIC FEE' );
}

sub poNetFee {
	my $self = shift;
	my ( $po ) = @_;
	return $self->val ( { PO => $po } , 'NET FEE' );
}

sub subProdBasicFee {
	my $self = shift;
	my ( $product ) = @_;
	return $self->val ( { SUB-PRODUCT => $product } , 'BASIC FEE' );
}

sub subProdNetFee {
	my $self = shift;
	my ( $product ) = @_;
	return $self->val ( { SUB-PRODUCT => $product } , 'NET FEE' );
}

1;
