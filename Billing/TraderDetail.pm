package TraderDetail;

use Data::Dumper;

BEGIN {
	require CSVFile;
	push @ISA , 'CSVFile';
}

use strict;

sub new {
	my $class = shift;

	my $self = $class->SUPER::new ( 
					file	=> undef ,
					keyFlds => [ 'TRADER_ID' , 'ACCT_TYPE' , 'Symbol' , 'PRODUCT' ] ,
					ignoreFlds => [ 'MARKET' ] ,
					@_ 
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

sub totalVol {
	my $self = shift;
	my $vol = 0;
	foreach my $sym ( $self->keys ( 'Symbol' ) ) {
		$vol += $self->symbolVol ( $sym );
	}
	return $vol;
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

sub traderVol {
	my $self = shift;
	my ( $trdrID ) = @_;
	my $totalVol = 0;
	foreach my $sym ( $self->keys ( 'Symbol' ) ) {
		my $vol = $self->val ( { TRADER_ID => $trdrID , Symbol => $sym } , 'TOTAL_VOLUME' );
		$vol = transformQty ( $sym , $vol );
		$totalVol += $vol;
	}
	return $totalVol;
}

sub symbolBasicFee {
	my $self = shift;
	my ( $sym ) = @_;
	return $self->val ( { Symbol => $sym } , 'BASIC_FEE' );
}

sub symbolNetFee {
	my $self = shift;
	my ( $sym ) = @_;
	return $self->val ( { Symbol => $sym } , 'NET_FEE' );
}

sub symbolVol {
	my $self = shift;
	my ( $sym ) = @_;
	return $self->val ( { Symbol => $sym } , "TOTAL_VOLUME" );
}

sub subProdBasicFee {
	my $self = shift;
	my ( $subProd ) = @_;
	return $self->val ( { PRODUCT => $subProd } , 'BASIC_FEE' );
}

sub subProdNetFee {
	my $self = shift;
	my ( $subProd ) = @_;
	return $self->val ( { PRODUCT => $subProd } , 'NET_FEE' );
}

sub subProdVol {
	my $self = shift;
	my ( $subProd ) = @_;
	return $self->val ( { PRODUCT => $subProd } , "TOTAL_VOLUME" );
}

1;
