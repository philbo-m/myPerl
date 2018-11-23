package Quote;

use strict;

use Util;

sub new {
	my $class = shift;
	my $self = {
		ABBO 	=> [ '' , '' ] ,
		LBBO	=> [ '' , '' ] ,
		Vol		=> [ '' , '' ] ,
		NBBO	=> [ '' , '' ] ,
		@_
	};
	
	return bless $self;
}

sub add {
	my $self = shift;
	
	my ( $bid , $ask , $bidVol , $askVol , $isLocal ) = @_;
	my $bbo = ( $isLocal ? $self->{LBBO} : $self->{ABBO} );
	$self->{Event} = ( $isLocal ?
						"LBBO : $self->{Vol}[ 0 ]|$self->{LBBO}[ 0 ] - $self->{LBBO}[ 1 ]|$self->{Vol}[ 1 ] ==> $bidVol|$bid - $ask|$askVol" :
						"ABBO : $self->{ABBO}[ 0 ] - $self->{ABBO}[ 1 ] ==> $bid - $ask"
					);
	@$bbo = ( $bid , $ask );
	@{ $self->{NBBO} } = ( Util::max ( $self->{LBBO}[ 0 ] , $self->{ABBO}[ 0 ] ) ,
							!$self->{LBBO}[ 1 ] ? $self->{ABBO}[ 1 ] :
								!$self->{ABBO}[ 1 ] ? $self->{LBBO}[ 1 ] :
								Util::min ( $self->{LBBO}[ 1 ] , $self->{ABBO}[ 1 ] ) 
						);
	if ( $isLocal ) {
		@{ $self->{Vol} } = ( $bidVol , $askVol );
	}
}

sub isNBBOLocal {
	my $self = shift;
	my ( $side ) = @_;

#	--- Will break if no LBBO ---	
	return ( $side eq 'BID' ? 
				$self->{LBBO}[ 0 ] >= $self->{NBBO}[ 0 ] :
				$self->{LBBO}[ 1 ] <= $self->{NBBO}[ 1 ]
			);
}	

sub getPrice {
	my $self = shift;
	my ( $side , $which ) = @_;
	$which = 'NBBO' if !$which;
	
	return $self->{ $which }[ ( $side eq 'BID' ? 0 : 1 ) ];
}

sub auditBBO {
	my $self = shift;
	
	my ( $bid , $ask , $bidVol , $askVol ) = @_;
	my $bbo = $self->{LBBO};
	
	return ( $bid == $self->{LBBO}[ 0 ] && $ask == $self->{LBBO}[ 1 ]
			&& $bidVol == $self->{Vol}[ 0 ] && $askVol == $self->{Vol}[ 1 ] );
}		

sub clone {
	my $self = shift;

	my $that = new Quote (
					ABBO	=> [ $self->{ABBO}[ 0 ] , $self->{ABBO}[ 1 ] ] ,
					LBBO	=> [ $self->{LBBO}[ 0 ] , $self->{LBBO}[ 1 ] ] ,
					Vol		=> [ $self->{Vol}[ 0 ] , $self->{Vol}[ 1 ] ] ,
					NBBO	=> [ $self->{NBBO}[ 0 ] , $self->{NBBO}[ 1 ] ]
				);
	return $that;
}	
	
sub dump {
	my $self = shift;
	my ( $lclOnly ) = @_;
	
	my @output = ( @{ $self->{LBBO} } , @{ $self->{Vol} } );
	if ( !$lclOnly ) {
		push @output , ( @{ $self->{ABBO} } , @{ $self->{NBBO} } );
	}
	return join ( " " , @output );
}

1;