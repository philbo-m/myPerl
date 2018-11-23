#!c:/perl/bin/perl

my %llMap;

while ( <> ) {

	print STDERR "$.\n" if ( !( $. % 100000 ) );
	
	next if ( ! /\s(Sending|Receiving)\s:\s/ || /\s<.*\/>$/ || /\[I_/ || /_RELAY/ );
	chomp;
	
	my ( $date , $time , $thread , $plugin , $lvl , $dir , undef , $msg ) = split ( /\s+/ , $_ , 8 );
	$plugin =~ s/^\[O_(.*)\]/$1/;
	
	my @msg = split ( /(?:\||^)(\d+)=/ , $msg );
	shift @msg;
	my %msg = @msg;
	
	my ( $sym , $msgType , $clOrdID , $origClOrdID , $longLife )
		= ( $msg{ 55 } , $msg{ 35 } , $msg{ 11 } , $msg{ 41 } , $msg{ 7735 } );
		
	if ( $msgType eq 'D' && $longLife ) {
		$llMap{ $plugin }{ $clOrdID } = 1;
	}
	elsif ( $msgType =~ /[FG]/ && $origClOrdID && exists $llMap{ $plugin }{ $origClOrdID } ) {
		if ( exists $llMap{ $plugin }{ $clOrdID } ) {
			print STDERR "WARNING : LL [$clOrdID] already exists\n";
		}
		else {
			$llMap{ $plugin }{ $clOrdID } = 1;
		}
	}
}

foreach my $plugin ( sort keys %llMap ) {
	foreach my $clOrdID ( sort keys %{ $llMap{ $plugin } } ) {
		print "$plugin,$clOrdID\n";
	}
}