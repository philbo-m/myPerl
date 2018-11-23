package Activ::ActivFile;

use strict;
use Data::Dumper;

use Activ::ActivMsg;

my $DEF_BUF_SIZE = 1000;

sub new {
	my $class = shift;
	my $self = {
					File => undef ,
					msgBuf => [] ,
					maxBuf => $DEF_BUF_SIZE ,
					@_
				};

	if ( !$self->{File} ) {
		$self->{FH} = *STDIN;
	}
	elsif ( !ref ( $self->{File} ) ) {
		open ( $self->{FH} , $self->{File} ) or die ( "Cannot open [$self->{File}] : $!" );
	}

	$self->{bufSize} = 0;
	foreach ( @{ $self->{msgBuf} } ) {
		$self->{bufSize} += scalar $$_[ 1 ];
	}
	
	return bless $self;
}

sub _applyToMsgBuf {
	my $self = shift;
	my ( $msg ) = @_;
	my $ts = $msg->timeStamp ();
	
	my ( $startIdx , $endIdx , $applyIdx ) = ( 0 , $#{ $self->{ msgBuf } } , undef );
	
#	Check to see if we can simply append our message, which hopefully will be much of the time.
#	-------------------------------------------------------------------------------------------
	my $endTS = ( $endIdx == -1 ? '' : ${ $self->{ msgBuf } }[ $endIdx ][ 0 ] );

	if ( $ts gt $endTS ) {
		push @{ $self->{ msgBuf } } , [ $ts , [] ];
		$applyIdx = $endIdx + 1;
#		print STDERR "Appending [$ts] beyond [$endTS] at new end index [$applyIdx]...\n";
	}
	elsif ( $ts eq $endTS ) {
		$applyIdx = $endIdx;
#		print STDERR "Applying [$ts] at end idx [$applyIdx]...\n";
	}
	else {
	
#		No such luck.  Binary-search thru the msg buffer to discover where to insert our message.
#		-----------------------------------------------------------------------------------------
		while ( $startIdx < $endIdx ) {
			my $midIdx = sprintf "%d" , ( $endIdx + $startIdx ) / 2;
			my $midTS = ${ $self->{ msgBuf } }[ $midIdx ][ 0 ];
#			print STDERR "Looking for [$ts] at [$midIdx] [$midTS] between [$startIdx] and [$endIdx]...\n";
			if ( $ts eq $midTS ) {
				$applyIdx = $midIdx;
				last;
			}
			elsif ( $ts lt $midTS ) {
				$endIdx = $midIdx - 1;
			}
			elsif ( $ts gt $midTS ) {
				$startIdx = $midIdx + 1;
			}
		}
#		print STDERR "Narrowed it down to index [$startIdx] [${ $self->{ msgBuf } }[ $startIdx ][ 0 ]] [$endIdx] [${ $self->{ msgBuf } }[ $endIdx ][ 0 ]] ...\n";
		
		if ( !$applyIdx ) {
			$applyIdx = $startIdx;
			my $startTS = ${ $self->{ msgBuf } }[ $applyIdx ][ 0 ];
			if ( $ts ne $startTS ) {
				$applyIdx++ if $ts gt $startTS;
				splice ( @{ $self->{ msgBuf } } , $applyIdx , 0 , [ $ts , [] ] );
			}
		}
	}
	
#	After all that, add the message to the proper array.
#	----------------------------------------------------
	push @{ $self->{ msgBuf }[ $applyIdx ][ 1 ] } , $msg;
	$self->{ bufSize }++;
}

sub _popMsgBuf {
	my $self = shift;
	return undef if $self->{ bufSize } == 0;

	my $subBuf = $self->{ msgBuf }[ 0 ][ 1 ];
	my $msg = shift @$subBuf;
	if ( $#$subBuf == -1 ) {
		shift @{ $self->{ msgBuf } };
	}
	
	$self->{ bufSize }--;
	return $msg;
}

sub next {
	my $self = shift;
	
	if ( ( !defined $self->{FH} ) && !$self->{bufSize} ) {	# --- no more input and buffer empty ---
		return undef;
	}
	
	if ( $self->{FH} && $self->{bufSize} < $self->{maxBuf} / 2 ) {
		print STDERR "Need to replenish [" , $self->{maxBuf} - $self->{bufSize} , "] recs from [$self->{FH}]...\n";
		while ( $self->{bufSize} < $self->{maxBuf} ) {
			my $msg;
			while ( readline ( $self->{FH} ) ) {
				chomp;
				print STDERR "$.\n" if ( !( $. % 100000 ) );
				$msg = new Activ::ActivMsg ( $_ );
				last if $msg;
			}
			if ( !$msg ) {
				$self->{FH} = undef;
				last;
			}
			
			$self->_applyToMsgBuf ( $msg );
		}
#		print STDERR Dumper ( $self->{ msgBuf } ) , "\n";
	}
	
	return $self->_popMsgBuf;
}

1;