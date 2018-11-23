package STAMP;

use STAMPFld;

sub new {
	my $class = shift;
	my $self = {
		file		=> undef ,
		bufSize		=> 10000000 ,
		@_
	};

	if ( $self->{file} ) {
		if ( !ref $self->{file} ) {
			if ( !open FILE , $self->{file} ) {
				print STDERR "Could not open STAMP file [$self->{file}] : $!\n";
				return;
			}
			$self->{file} = \*FILE;
		}
	}
	
	$self->{recBuf} = [];
	$self->{recSep} = chr ( 0x01 );
	$self->{busCont} = chr ( 0x1c );
	$self->{fldSep} = chr ( 0x1e );
	
	return bless $self;
}

sub getRec {
	my $self = shift;
	
	if ( $#{ $self->{recBuf} } <= 0 ) {
	
#		No records in buffer, or one (probably partial) record.
#		-------------------------------------------------------
#		print STDERR "BUF REMNANT : [${ $self->{recBuf} }[ 0 ]]\n";
		my $fh = $self->{file};
		local $/ = \$self->{bufSize};
		my $chunk = ${ $self->{recBuf} }[ 0 ] . <$fh>;
#		print STDERR "Buffer now [" , length $chunk , "] [" , substr ( $chunk , 0 , 20 ) , "]\n";
		$self->{recBuf} = [ split ( /$self->{recSep}/ , $chunk , -1 ) ];
#		print STDERR "First rec now [" ,${$self->{recBuf}}[ 0 ] , "]\n";

	}
	
	return shift @{ $self->{recBuf} };	
}

sub mkFldPtrn {
	my $self = shift;
	my ( $flds ) = @_;

	my @flds = map {
			my ( $f , $idx ) = split /\./;
			my $v = $STAMPFld::revTagMap{ $f };
			$v ? $v . ( defined $idx ? ".$idx" : "" ) : $_;
		} @$flds;
	my $fldPtrn = "^(" . join ( "|" , @flds ) . ")=";

	return $fldPtrn;
}

sub getFlds {
	my $self = shift;
	my ( $rec , $flds ) = @_;
	
	my $fldPtrn;
	if ( ref ( $flds ) eq 'ARRAY' ) {
		$fldPtrn = $self->mkFldPtrn ( $flds );
	}
	else {
		$fldPtrn = $flds;
	}
	
	my %h = map {
		/^(\d+)(\.\d)?=(.*)$/;
		$STAMPFld::tagMap{ $1 } . $2 => $3						# --- convert Key=Value field into Key => Value hash entry ---
	} grep {
		/$fldPtrn/												# --- pull out only the fields we're interested in ---
	} split ( /[$self->{busCont}$self->{fldSep}]+/ , $rec );	# --- split records into Key=Value fields ---
	
	return \%h;
}

sub getFld {
	my $self = shift;
	my ( $rec , $fld ) = @_;
	my $fldPtrn = "[$self->{busCont}$self->{fldSep}]+${fld}=([^$self->{busCont}$self->{fldSep}]+)";
	my $fldVal = ( $rec =~ /$fldPtrn/ );
	
	return $fldVal;
}

1;