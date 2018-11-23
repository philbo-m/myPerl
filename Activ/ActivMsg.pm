package Activ::ActivMsg;

use strict;

use Activ::ActivNBBOMsg;
use Activ::ActivTradeMsg;

our %msgTypeMap = (
	
	1	=> "TRADE" ,
	3	=> "NBBO"
);

our %exchMap = (
	AQL		=> 'AEQ' ,
	AQN		=> 'NEO' ,
	ATS		=> 'ALM' ,
	CHIC	=> 'CHIX' ,
	CX2		=> 'CX2' ,
	CXD		=> 'CXD' ,
	LYX		=> 'LYNX' ,
	OMG		=> 'OMEGA' ,
	PT		=> 'CSE' ,
	TO		=> 'TSX' ,
	TV		=> 'TSXV'
);

our %tagMap = (
	0		=> 'BID_PRICE' ,
	1		=> 'BID_SIZE' ,
	2		=> 'BID_COND' ,
	3		=> 'BID_TIME' ,
	4		=> 'BID_EXCH' ,
	5		=> 'ASK_PRICE' ,
	6		=> 'ASK_SIZE' ,
	7		=> 'ASK_COND' ,
	8		=> 'ASK_TIME' ,
	9		=> 'ASK_EXCH' ,
	11		=> 'QUOTE_DATE' ,
	
	12		=> 'TRD_PRICE' ,
	13		=> 'TRD_SIZE' ,
	14		=> 'TRD_COND' ,
	15		=> 'TRD_TIME' ,
	16		=> 'TRD_DATE' ,
	17		=> 'TRD_EXCH' ,
	26		=> 'TRD_COUNT' ,
	50		=> 'CUM_PRICE' ,
	51		=> 'CUM_VAL' ,
	52		=> 'CUM_VOL' ,
	693		=> 'TRD_BUYER' ,
	694		=> 'TRD_SELLER' ,
	1128	=> 'TRD_ID'
);

our %revTagMap = map { $tagMap{ $_ } => $_ } keys %tagMap;

sub new {
	my $class = shift;
	my $rec = shift;
	my $self = {};
	
	my @flds = ( split /\|/ , $rec );
	
	my ( $timeStamp , $msgTypeID , $sym ) = @flds[ 2 , 7 , 8 ];

	my $msgType = $msgTypeMap{ $msgTypeID };
	if ( $msgType eq 'TRADE' ) {
		$self = bless $self , "Activ::ActivTradeMsg";
	}
	elsif ( $msgType eq 'NBBO' ) {
		$self = bless $self , "Activ::ActivNBBOMsg";
	}
	else {
		return undef;
	}

	
#	Cut off the prefix and trailing newline.
#	----------------------------------------
	splice ( @flds , 0 , 10 );
	
	$self->{fldMap} = { 
				map { 
					my @kv = split /=/ ; 
					$kv[ 1 ] = '' if !defined $kv[ 1 ] ;
					( exists $tagMap{ $kv[ 0 ] } ? $tagMap{ $kv[ 0 ] } : $kv[ 0 ] ) => $kv[ 1 ] 
				} @flds 
			};

	$self->{fldMap}->{MSG_TYPE} = $msgType;
	$self->{fldMap}->{TIMESTAMP} = $timeStamp;
	$self->{fldMap}->{SYMBOL} = $sym;

	return $self;
}

sub getFld {
	my $self = shift;
	my ( $fldName ) = @_;
	
	return exists $self->{fldMap}->{ $fldName } ? $self->{fldMap}->{ $fldName } : undef;
}

# --- SUBCLASSES MUST OVERRIDE THIS ---
sub timeStamp {
	my $self = shift;
	return undef;
}

sub showMsg  {
	my $self = shift;
	my ( $fldList ) = @_;
	
	if ( !scalar @$fldList ) {
		my @allFldList = qw ( TIMESTAMP MSG_TYPE SYMBOL );
		push @allFldList , grep { $_ !~ /^(TIMESTAMP|MSG_TYPE|SYMBOL)$/ } sort keys %{ $self->{ fldMap } };
		return join ( "\n" , map { "$_ = $self->{ fldMap }->{ $_ }" } @allFldList );
	}
	else {
		return join ( "," , map { $self->{ fldMap }->{ $_ } } @$fldList );
	}
}
	
1;

