package AlphaTraderDetail;

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
					keyFlds => [ 'TRADER_ID' , 'SYMBOL' , 'ACCT_TYPE' , 'PRODUCT' ] ,
					ignoreFlds => [ 'MARKET' , 'VOL <= CAP' , 'CAPPED_TRADES' ] ,
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
	foreach my $sym ( $self->keys ( 'SYMBOL' ) ) {
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
	foreach my $sym ( $self->keys ( 'SYMBOL' ) ) {
		my $vol = $self->val ( { TRADER_ID => $trdrID , SYMBOL => $sym } , 'TOTAL_VOLUME' );
		$vol = transformQty ( $sym , $vol );
		$totalVol += $vol;
	}
	return $totalVol;
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

sub symbolVol {
	my $self = shift;
	my ( $sym ) = @_;
	return $self->val ( { SYMBOL => $sym } , "TOTAL_VOLUME" );
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
