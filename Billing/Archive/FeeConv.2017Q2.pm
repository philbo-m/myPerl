package FeeConv;

our %feeMap = ( 
	OLD => {
		T_HI_CLOB				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_JIT		=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_INTL		=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_JIT_INTL	=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_LL			=> { PSV => -0.0019 } ,
		T_HI_CLOB_JIT_LL		=> { PSV => -0.0019 } ,
		T_HI_CLOB_ETF_LL		=> { PSV => -0.0019 } ,
		T_HI_CLOB_ETF_JIT_LL	=> { PSV => -0.0019 } ,
		
		T_HI_DARK_LIT			=> { ACT => 0.0023 } ,
		T_HI_DARK_LIT_ETF		=> { ACT => 0.0023 } ,
		T_HI_DARK_LIT_ETF_INTL	=> { ACT => 0.0023 } ,
		
		T_MOC					=> { ACT => 0.0030 , CAP => 30 } ,
		
		T_HI_RT					=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_HI_RT_LL				=> { PSV => -0.0027 } ,
		T_HI_ETF_RT				=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_HI_ETF_RT_INTL		=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_HI_ETF_RT_LL			=> { PSV => -0.0027 } ,
		T_HI_RT_ETF_INTL_LL		=> { PSV => -0.0027 } ,
		T_HI_MOC_RT				=> { PSV => 0.0006 } ,
		T_LO_MOC_RT				=> { PSV => 0.0003 } ,
		
		T_HI_MGF				=> { ACT => 0.0030 } ,
		T_HI_MOC_AUTOFILL		=> { ACT => 0.0010 } ,
		T_LO_MOC_AUTOFILL		=> { ACT => 0.0005 } ,
		
		V_HI_CLOB				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_CLOB_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_CLOB_LL			=> { PSV => -0.0019 } ,
		V_HI_CLOB_JIT_LL		=> { PSV => -0.0019 } ,
		V_HI_DEBT_LL			=> { PSV => -0.0019 } ,
		V_HI_DEBT_JIT_LL		=> { PSV => -0.0019 } ,	
		
		V_HI_DARK_LIT			=> { ACT => 0.0023 } ,
		
		V_MOC					=> { ACT => 0.0012 , CAP => 60 } ,
		
		V_HI_VOD				=> { ACT => 0.0023 , PSV => -0.0027 } ,
		V_HI_VOD_LL				=> { PSV => -0.0027 } ,
	} , 
	
	NEW => {
		T_HI_CLOB				=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_JIT			=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_ETF			=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_ETF_JIT		=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_ETF_INTL		=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_ETF_JIT_INTL	=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_LL			=> { PSV => -0.0011 } ,
		T_HI_CLOB_JIT_LL		=> { PSV => -0.0011 } ,
		T_HI_CLOB_ETF_LL		=> { PSV => -0.0011 } ,
		T_HI_CLOB_ETF_JIT_LL	=> { PSV => -0.0011 } ,
		
		T_HI_DARK_LIT			=> { ACT => 0.0015 } ,
		T_HI_DARK_LIT_ETF		=> { ACT => 0.0015 } ,
		T_HI_DARK_LIT_ETF_INTL	=> { ACT => 0.0015 } ,
		
		T_MOC					=> { ACT => 0.0030 , CAP => 30 } ,
		T_HI_MOC				=> { ACT => 0.0030 , CAP => 30 } ,
		T_LO_MOC				=> { ACT => 0.0030 , CAP => 30 } ,
		
		T_HI_RT					=> { ACT => 0.0015 , PSV => -0.0019 } ,
		T_HI_RT_LL				=> { PSV => -0.0019 } ,
		T_HI_ETF_RT				=> { ACT => 0.0015 , PSV => -0.0019 } ,
		T_HI_ETF_RT_INTL		=> { ACT => 0.0015 , PSV => -0.0019 } ,
		T_HI_ETF_RT_LL			=> { PSV => -0.0019 } ,
		T_HI_RT_ETF_INTL_LL		=> { PSV => -0.0019 } ,
		T_HI_MOC_RT				=> { PSV => 0.0000 } ,
		T_LO_MOC_RT				=> { PSV => 0.0000 } ,
		
		T_HI_MGF				=> { ACT => 0.0017 } ,
		T_HI_MOC_AUTOFILL		=> { ACT => 0.0005 } ,
		T_LO_MOC_AUTOFILL		=> { ACT => 0.00025 } ,
		
		V_HI_CLOB				=> { ACT => 0.0015 , PSV => -0.0011 } ,
		V_HI_CLOB_JIT			=> { ACT => 0.0015 , PSV => -0.0011 } ,
		V_HI_DEBT				=> { ACT => 0.0015 , PSV => -0.0011 } ,
		V_HI_DEBT_JIT			=> { ACT => 0.0015 , PSV => -0.0011 } ,
		V_HI_CLOB_LL			=> { PSV => -0.0011 } ,
		V_HI_CLOB_JIT_LL		=> { PSV => -0.0011 } ,
		V_HI_DEBT_LL			=> { PSV => -0.0011 } ,
		V_HI_DEBT_JIT_LL		=> { PSV => -0.0011 } ,	
		
		V_HI_DARK_LIT			=> { ACT => 0.0015 } ,
		
		V_MOC					=> { ACT => 0.0012 , CAP => 60 } ,
		V_HI_MOC				=> { ACT => 0.0012 , CAP => 60 } ,
		V_LO_MOC				=> { ACT => 0.0012 , CAP => 60 } ,
		
		V_HI_VOD				=> { ACT => 0.0015 , PSV => -0.0019 } ,
		V_HI_VOD_LL				=> { PSV => -0.0019 } ,
	}
);

my @toastProds = ();
our %toastMap = map { $_ => 1 } @toastProds;

our %collapseMap = (
	NEW => {
		T_MOC					=> [ qw ( T_HI_MOC T_LO_MOC ) ] ,
		V_MOC					=> [ qw ( V_HI_MOC V_LO_MOC ) ] ,
		
	}
);

# Relevant sub-products whose Account Summ records' Active Fee/Passive Credit fields are zero
# -------------------------------------------------------------------------------------------
our @noActPsvFeeProds = (
		"NEX" , "NEX_LL" , "T_DEBT" , "T_DEBT_LL" , "T_EXCH" , "T_HI_CLOB_CORR" , "T_HI_MGF" , "T_HI_MGF_CORR" , 
		"T_HI_MGF_INTL" , "T_HI_OL" , "T_LO_CLOB_CORR" , "T_LO_MGF" , "T_LO_MGF_CORR" , "T_LO_OL" , "T_MBF" , 
		"T_MOC" , "T_HI_MOC" , "T_LO_MOC" , "T_MOO" , "T_MOO_CORR" , "T_ST" , "V_EXT" , "V_EXT_CORR" , "V_HI_CLOB_CORR" , 
		"V_HI_OL_AUTOFILL" , "V_LO_CLOB_CORR" , "V_LO_T1_OL_AUTOFILL" , "V_LO_T2_OL_AUTOFILL" , "V_MOC" , "V_HI_MOC" ,
		"V_LO_MOC" , "V_MOO" , "V_MOO_CORR" , "V_MOO_DEBT"
	);

our %noActPsvFeeProds = map { $_ => 1 } @noActPsvFeeProds;

1;
