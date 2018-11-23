package STAMPMsg;

use strict;
use STAMPFld;

sub new {
	my $class = shift;
	my $self = {
		busContDelim	=> chr ( 0x1c ) ,
		fldSep			=> chr ( 0x1e ) ,
		showTags	=> undef ,
		filter		=> undef ,
		@_
	};
	
	bless $self;
	$self->init;
	
	return $self;
}

sub init {
	my $self = shift;

	$self->{raw} = '';
	$self->{isInbound} = undef;
	$self->{timeStamp} = undef;
	$self->{flds} = ();
	$self->{fldMap} = ();
}

sub parse {
	my $self = shift;
	my ( $rec ) = @_;

	my ( $ctrlFlds , $busFlds ) = split ( /$self->{busContDelim}/ , $rec );
	foreach my $flds ( $ctrlFlds , $busFlds ) {
		my @flds = split ( /$self->{fldSep}/ , $flds );
		foreach my $fld ( @flds ) {
			next if !$fld;
			my ( $tag, $val ) = split ( /=/ , $fld );
			$self->addFld ( $tag , $val );
		}
	}
}

sub addFld {
	my $self = shift;
	my ( $tag , $val ) = @_;
	if ( !defined $val ) {
		( $tag , $val ) = split /=/ , $tag;
	}

	my $fld = new STAMPFld ( $tag , $val );	# --- $fld->{tag} might not wind up the same as $tag ---
	if ( ( !scalar keys %{ $self->{showTags} } || exists $self->{showTags}{ $fld->{tag} } )
			|| !defined $val ) {
		push @{ $self->{flds} } , $fld;
		${ $self->{fldMap} }{ $fld->{tag} } = $fld;
		
		if ( !$self->{timeStamp} && $fld->{timeStamp} ) {
			$self->{timeStamp} = $fld->{timeStamp};
		}
	}
}

sub desc {
	my $self = shift;

	if ( !$self->{desc} ) {
		$self->{desc} = ( $self->{timeStamp} ? "$self->{timeStamp} : " : "" );
	}
	return $self->{desc};
}

sub dump {
	my $self = shift;
	my ( $showUniqId ) = @_;
	
	my @strs = ();
	if ( $showUniqId ) {
		push @strs , "UniqId = " . $self->uniqId;
	}
	foreach my $fld ( @{ $self->{flds} } ) {
		push @strs , $fld->dump;
	}
	return ( $self->{timeStamp} ? "$self->{timeStamp}:\n" : "" )
			. join ( "\n" , @strs ) . "\n";
}

1;
