package BillingScenario;

require Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw ( @invalidScenarios );

our @invalidScenarios = (
	{
		EXCHANGE_ID		=> 'TSX' ,
		SYMBOL_GROUP	=> '3'
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		SYMBOL_GROUP	=> '4'
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		SYMBOL_GROUP	=> '5'
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		SYMBOL_GROUP	=> '6'
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		SYMBOL_GROUP	=> '7'
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		SYMBOL_GROUP	=> '8'
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		PRIVATE_ORIG_PR	=> 'MBF' ,
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		MGF				=> 'Y' ,
	} ,	
	{
		EXCHANGE_ID		=> 'TSXV' ,
		SYM_INTERLISTED	=> 'Y' ,
	} ,
	{
		EXCHANGE_ID		=> 'TSXV' ,
		SETTLEMENT_TERM	=> 'Y' ,
	} ,
);

1;