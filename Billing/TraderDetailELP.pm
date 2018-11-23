package TraderDetailELP;

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
					keyFlds => [ 'ELP GroupID' , 'ELP Trader ID' , 'Symbol' ] ,
					ignoreFlds => [ 'ELP Detail' ] ,
					@_ 
				);

	$self->parse ( $self->{file} );
	
	return bless $self;
}


sub totalNetFee {
	my $self = shift;
	return $self->val ( {} , 'ELP Net Fee' );
}

sub traderNetFee {
	my $self = shift;
	my ( $trdrID ) = @_;
	return $self->val ( { "ELP Trader ID" => $trdrID } , 'ELP Net Fee' );
}

sub groupNetFee {
	my $self = shift;
	my ( $grpID ) = @_;
	return $self->val ( { "ELP GroupID" => $grpID } , 'ELP Net Fee' );
}

sub traderActiveVol {
	my $self = shift;
	my ( $trdrID ) = @_;
	return $self->val ( { "ELP Trader ID" => $trdrID } , 'ELP Active Vol' );
}

sub traderPassiveVol {
	my $self = shift;
	my ( $trdrID ) = @_;
	return $self->val ( { "ELP Trader ID" => $trdrID } , 'ELP Passive Vol' );
}

sub groupActiveVol {
	my $self = shift;
	my ( $grpID ) = @_;
	return $self->val ( { "ELP GroupID" => $grpID } , 'ELP Active Vol' );
}

sub groupPassiveVol {
	my $self = shift;
	my ( $grpID ) = @_;
	return $self->val ( { "ELP GroupID" => $grpID } , 'ELP Passive Vol' );
}


1;
