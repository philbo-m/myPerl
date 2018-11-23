package FeeConv;

our %feeMap = ( 
	OLD => {
		T_HI_OL					=> { ACT => 0.0010 } ,
		T_LO_OL					=> { ACT => 0.0005 } ,
		T_HI_ETF_RT_OL			=> { PSV => -0.0006 } ,
		T_HI_RT_OL				=> { PSV => -0.0006 } ,
		T_LO_ETF_RT_OL			=> { PSV => -0.0003 } ,
		T_LO_RT_OL				=> { PSV => -0.0003 } ,
		T_HI_DARK_LIT_INTL		=> { ACT => 0.0030 } ,
		T_HI_CLOB_JIT_INTL		=> { ACT => 0.0030 , PSV => -0.0026 } ,
		T_HI_CLOB_INTL			=> { ACT => 0.0030 , PSV => -0.0026 } ,
		T_HI_CLOB_JIT_INTL_LL	=> { PSV => -0.0026 } ,
		T_HI_CLOB_INTL_LL		=> { PSV => -0.0026 } ,
		T_HI_RT_INTL			=> { ACT => 0.0030 } ,
		T_LO_MGF				=> { ACT => 0.0010 } ,
		
		NEX						=> { ACT => 0.0005 , PSV => 0.0005 } ,
		NEX_LL					=> { ACT => 0.0005 , PSV => 0.0005 } ,
		
		V_HI_OL_AUTOFILL		=> { ACT => 0.0010 } ,
		V_HI_MOC_AUTOFILL		=> { ACT => 0.0010 } , 
		V_HI_VOD_OL_AUTOFILL	=> { PSV => -0.0006 } ,
		V_HI_MOC_VOD			=> { PSV => -0.0006 } ,
		V_LO_VOD_OL_AUTOFILL	=> { PSV => -0.00005 } ,
		V_LO_MOC_VOD			=> { PSV => -0.00005 }
	} , 
	NEW => {
		T_HI_OL					=> { ACT => 0.0005 } ,
		T_LO_OL					=> { ACT => 0.00025 } ,
		T_HI_ETF_RT_OL			=> { PSV => -0.0000 } ,
		T_HI_RT_OL				=> { PSV => -0.0000 } ,
		T_LO_ETF_RT_OL			=> { PSV => -0.0000 } ,
		T_LO_RT_OL				=> { PSV => -0.0000 } ,
		T_HI_DARK_LIT_INTL		=> { ACT => 0.0027 } ,
		T_HI_CLOB_JIT_INTL		=> { ACT => 0.0027 , PSV => -0.0023 } ,
		T_HI_CLOB_INTL			=> { ACT => 0.0027 , PSV => -0.0023 } ,
		T_HI_CLOB_JIT_INTL_LL	=> { PSV => -0.0023 } ,
		T_HI_CLOB_INTL_LL		=> { PSV => -0.0023 } ,
		T_HI_RT_INTL			=> { ACT => 0.0027 } ,
		T_LO_MGF				=> { ACT => 0.0004 } ,
		
		NEX						=> { ACT => 0.0004 , PSV => 0.0004 } ,
		NEX_LL					=> { ACT => 0.0004 , PSV => 0.0004 } ,
		
		V_HI_OL_AUTOFILL		=> { ACT => 0.0005 } ,
		V_HI_MOC_AUTOFILL		=> { ACT => 0.0005 } , 
		V_HI_VOD_OL_AUTOFILL	=> { PSV => 0.0000 } ,
		V_HI_MOC_VOD			=> { PSV => 0.0000 } ,
		V_LO_VOD_OL_AUTOFILL	=> { PSV => 0.0000 } ,
		V_LO_MOC_VOD			=> { PSV => 0.0000 }
	}
);

my @toastProds = qw ( T_EXCH T_EXCH_RT T_RW T_RW_CPF_OPN T_RW_LL T_RW_RT T_RW_RT_LL );
our %toastMap = map { $_ => 1 } @toastProds;

our %collapseMap = (
	NEW => {
	}
);

# Relevant sub-products whose Account Summ records' Active Fee/Passive Credit fields are zero
# -------------------------------------------------------------------------------------------
our @noActPsvFeeProds = (
		"NEX" , "NEX_LL" , "T_DEBT" , "T_DEBT_LL" , "T_EXCH" , "T_EXT" , "T_EXT_CORR" , "T_HI_CLOB_CORR" , "T_HI_MGF" , "T_HI_MGF_CORR" , 
		"T_HI_MGF_INTL" , "T_HI_OL" , "T_LO_CLOB_CORR" , "T_LO_MGF" , "T_LO_MGF_CORR" , "T_LO_OL" , "T_MBF" , 
		"T_MOC" , "T_MOO" , "T_MOO_CORR" , "T_RW_CPF_OPN" , "T_ST" , "V_EXT" , "V_EXT_CORR" , "V_HI_CLOB_CORR" , 
		"V_HI_OL_AUTOFILL" , "V_LO_CLOB_CORR" , "V_LO_T1_OL_AUTOFILL" , "V_LO_T2_OL_AUTOFILL" , "V_MOC" , 
		"V_MOO" , "V_MOO_CORR" , "V_MOO_DEBT"
	);

our %noActPsvFeeProds = map { $_ => 1 } @noActPsvFeeProds;

1;
