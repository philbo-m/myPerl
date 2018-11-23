package DeepHash;

use strict;
no strict 'refs';

use Data::Dumper;

our $WILDCARD = "*";

sub addToHash {
	my ( $hash , $flds , $val , $name ) = @_;
	
	my @lclFlds = @$flds;
	
	my $fld = shift @lclFlds;
	if ( !scalar @lclFlds ) {
		foreach ( $WILDCARD , $fld ) {
			$$hash{ $_ } += $val;
		}
	}
	else {
		foreach ( $WILDCARD , $fld ) {
			if ( !exists $$hash{ $_ } ) {
				$$hash{ $_ } = {};
			}
			addToHash ( $$hash{ $_ } , \@lclFlds , $val , $name );
		}
	}
}

sub new {
	my $class = shift;
	my $self = {
		@_
	};
	
	$self->{hash} = {};
		
	return bless $self;	
}

sub add {
	my $self = shift;
	my ( $flds , $val ) = @_;
	
	my @tempFlds = @$flds;
	addToHash ( $self->{hash} , \@tempFlds , $val , $self->{Name} );
}

sub delete {
	my $self = shift;
	my ( $flds ) = @_;
	my $val = $self->val ( $flds );
	
	$self->add ( $flds , $val * -1 );

	my $evalStr = "delete \$self->{hash}{ \"" . join ( "\" }{ \"" , @$flds ) . "\" }";
	eval $evalStr; 
	print STDERR "...[$@]\n" if $@;

}

sub val {
	my $self = shift;
	my ( $flds ) = @_;
	
	my $hash = $self->{hash};
	foreach my $fld ( @$flds ) {
		$fld = $WILDCARD if !defined $fld;
		if ( !exists $$hash{ $fld } ) {
			return undef;
		}
		$hash = $$hash{ $fld };
	}
	return $hash;	# --- should be a value at this point ---
}

sub keys {
	my $self = shift;
	my ( $hash ) = @_;
	
	$hash = $self->{hash} if !$hash;
	
	my @keyList = ();
	
	foreach my $key ( grep { $_ ne $WILDCARD } keys %$hash ) {
		if ( ref $$hash{ $key } ne 'HASH' ) {
			push @keyList , [ $key ];
		}
		else {
			my $subKeyList = $self->keys ( $$hash{ $key } );
			foreach ( @$subKeyList ) {
				push @keyList , [ $key , @$_ ];
			}
		}
	}

	return \@keyList;
}


1;
