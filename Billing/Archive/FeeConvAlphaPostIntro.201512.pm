package FeeConvAlpha;

our %feeMap = ( 
	OLD => {
		"TSX High T1 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSX High T1 CLOB Regular Post-Only"	=> { PSV => 0.0010 } ,
		"TSX High T2 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSX High T2 CLOB Regular Post-Only"	=> { PSV => 0.0010 } ,
		"TSX High T1 CLOB Iceberg"	=> { PSV => 0.0010 } ,
		"TSX High T1 CLOB Iceberg Post-Only"	=> { PSV => 0.0010 } ,
		"TSX High T2 CLOB Iceberg"	=> { PSV => 0.0010 } ,
		"TSX High T2 CLOB Iceberg Post-Only"	=> { PSV => 0.0010 } ,
		"TSX High T1 ETF"			=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSX High T1 ETF Post-Only"			=> { PSV => 0.0010 } ,
		"TSX High T2 ETF"			=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSX High T2 ETF Post-Only"			=> { PSV => 0.0010 } ,
		"TSX High T1 ETF Iceberg"	=> { PSV => 0.0010 } ,
		"TSX High T1 ETF Iceberg Post-Only"	=> { PSV => 0.0010 } ,
		"TSX High T2 ETF Iceberg"	=> { PSV => 0.0010 } ,
		"TSX High T2 ETF Iceberg Post-Only"	=> { PSV => 0.0010 } ,
		"TSX Low CLOB Regular"		=> { ACT => -0.0006 , PSV => 0.0006 } ,
		"TSX Low CLOB Regular Post-Only"		=> { PSV => 0.0006 } ,
		"TSX Low CLOB Iceberg"		=> { PSV => 0.0006 } ,
		"TSX Low CLOB Iceberg Post-Only"		=> { PSV => 0.0006 } ,
		"TSX High T1 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSX High T2 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSX Low Oddlot Dealer"		=> { ACT => -0.0006 , PSV => 0.0006 } ,
		"TSX High T1 ETF Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSX High T2 ETF Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSXV High T1 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSXV High T1 CLOB Regular Post-Only"	=> { PSV => 0.0010 } ,
		"TSXV High T2 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSXV High T2 CLOB Regular Post-Only"	=> { PSV => 0.0010 } ,
		"TSXV High T1 CLOB Iceberg"	=> { PSV => 0.0010 } ,
		"TSXV High T1 CLOB Iceberg Post-Only"	=> { PSV => 0.0010 } ,
		"TSXV High T2 CLOB Iceberg"	=> { PSV => 0.0010 } ,
		"TSXV High T2 CLOB Iceberg Post-Only"	=> { PSV => 0.0010 } ,
		"TSXV Low CLOB Regular"		=> { ACT => -0.0006 , PSV => 0.0006 } , 
		"TSXV Low CLOB Regular Post-Only"		=> { PSV => 0.0006 } ,
		"TSXV Low CLOB Iceberg"		=> { PSV => 0.0006 } ,
		"TSXV Low CLOB Iceberg Post-Only"		=> { PSV => 0.0006 } ,
		"TSXV High T1 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSXV High T2 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0010 } ,
		"TSXV Low Oddlot Dealer"		=> { ACT => -0.0006 , PSV => 0.0006 } ,
	} ,
	NEW => {
		"TSX High T1 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0014 } ,
		"TSX High T1 CLOB Regular Post-Only"	=> { PSV => 0.0016 } ,
		"TSX High T2 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0014 } ,
		"TSX High T2 CLOB Regular Post-Only"	=> { PSV => 0.0016 } ,
		"TSX High T1 CLOB Iceberg"	=> { PSV => 0.0014 } ,
		"TSX High T1 CLOB Iceberg Post-Only"	=> { PSV => 0.0016 } ,
		"TSX High T2 CLOB Iceberg"	=> { PSV => 0.0014 } ,
		"TSX High T2 CLOB Iceberg Post-Only"	=> { PSV => 0.0016 } ,
		"TSX High T1 ETF"			=> { ACT => -0.0010 , PSV => 0.0014 } ,
		"TSX High T1 ETF Post-Only"			=> { PSV => 0.0016 } ,
		"TSX High T2 ETF"			=> { ACT => -0.0010 , PSV => 0.0014 } ,
		"TSX High T2 ETF Post-Only"			=> { PSV => 0.0016 } ,
		"TSX High T1 ETF Iceberg"	=> { PSV => 0.0014 } ,
		"TSX High T1 ETF Iceberg Post-Only"	=> { PSV => 0.0016 } ,
		"TSX High T2 ETF Iceberg"	=> { PSV => 0.0014 } ,
		"TSX High T2 ETF Iceberg Post-Only"	=> { PSV => 0.0016 } ,
		"TSX Low CLOB Regular"		=> { ACT => -0.0006 , PSV => 0.0010 } ,
		"TSX Low CLOB Regular Post-Only"		=> { PSV => 0.0012 } ,
		"TSX Low CLOB Iceberg"		=> { PSV => 0.0010 } ,
		"TSX Low CLOB Iceberg Post-Only"		=> { PSV => 0.0012 } ,
		"TSX High T1 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0014 } ,	# --- AOD post-only PSV rate is 0.0016 ---
		"TSX High T2 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0014 } ,	# --- AOD post-only PSV rate is 0.0016 ---
		"TSX Low Oddlot Dealer"		=> { ACT => -0.0006 , PSV => 0.0010 } ,	# --- AOD post-only PSV rate is 0.0012 ---
		"TSX High T1 ETF Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0014 } ,	# --- AOD post-only PSV rate is 0.0016 ---
		"TSX High T2 ETF Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0014 } ,	# --- AOD post-only PSV rate is 0.0016 ---
		"TSXV High T1 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0014 } ,
		"TSXV High T1 CLOB Regular Post-Only"	=> { PSV => 0.0016 } ,
		"TSXV High T2 CLOB Regular"	=> { ACT => -0.0010 , PSV => 0.0014 } ,
		"TSXV High T2 CLOB Regular Post-Only"	=> { PSV => 0.0016 } ,
		"TSXV High T1 CLOB Iceberg"	=> { PSV => 0.0014 } ,
		"TSXV High T1 CLOB Iceberg Post-Only"	=> { PSV => 0.0016 } ,
		"TSXV High T2 CLOB Iceberg"	=> { PSV => 0.0014 } ,
		"TSXV High T2 CLOB Iceberg Post-Only"	=> { PSV => 0.0016 } ,
		"TSXV Low CLOB Regular"		=> { ACT => -0.0006 , PSV => 0.0010 } , 
		"TSXV Low CLOB Regular Post-Only"		=> { PSV => 0.0012 } ,
		"TSXV Low CLOB Iceberg"		=> { PSV => 0.0010 } ,
		"TSXV Low CLOB Iceberg Post-Only"		=> { PSV => 0.0012 } ,
		"TSXV High T1 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0014 } , # --- AOD post-only PSV rate is 0.0016 ---
		"TSXV High T2 Odd lot Dealer"	=> { ACT => -0.0010 , PSV => 0.0014 } , # --- AOD post-only PSV rate is 0.0016 ---
		"TSXV Low Oddlot Dealer"		=> { ACT => -0.0006 , PSV => 0.0010 } , # --- AOD post-only PSV rate is 0.0012 ---
	} 
);
	
our %collapseMap = (
	OLD => {
	} ,
	NEW => {
	}
);

1;
