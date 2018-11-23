package FeeConv;

our %rateMap = ( 
	OLD => {
	} ,
	
	NEW => {

#		--- Collapse targets ---
		T_HI_DARK_DARK				=> { ACT => 0.0010 , PSV => 0 } ,
		T_HI_DARK_DARK_INTL			=> { ACT => 0.0010 , PSV => 0 } ,
		T_HI_DARK_DARK_ETF			=> { ACT => 0.0010 , PSV => 0 } ,
		T_LO_DARK_DARK_T1			=> { ACT => 0.000025 , PSV => 0 } ,
		T_LO_DARK_DARK_T2			=> { ACT => 0.000075 , PSV => 0 } ,
		V_HI_DARK_DARK				=> { ACT => 0.0010 , PSV => 0 } ,
		V_LO_DARK_DARK_T1			=> { ACT => 0.000025 , PSV => 0 } ,
		V_LO_DARK_DARK_T2			=> { ACT => 0.000075 , PSV => 0 } ,
	}
);

my @toastProds = ();
our %toastMap = map { $_ => 1 } @toastProds;
	
our %collapseMap = (
	NEW => {
		T_HI_DARK_DARK			=> [ qw ( T_HI_CMO T_HI_CMO_UNINT_CROSS ) ] ,
		T_HI_DARK_DARK_INTL		=> [ qw ( T_HI_CMO_INTL T_HI_CMO_UNINT_CROSS_INTL ) ] ,
		T_HI_DARK_DARK_ETF		=> [ qw ( T_HI_ETF_CMO T_HI_ETF_CMO_UNINT_CROSS ) ] ,
		T_LO_DARK_DARK			=> [ qw ( T_LO_CMO T_LO_CMO_UNINT_CROSS ) ] ,
		V_HI_DARK_DARK			=> [ qw ( V_HI_CMO V_HI_CMO_UNINT_CROSS ) ] ,
		V_LO_DARK_DARK			=> [ qw ( V_LO_CMO V_LO_CMO_UNINT_CROSS ) ] ,
	}
);

# Relevant sub-products whose Account Summ records' Active Fee/Passive Credit fields are zero
# -------------------------------------------------------------------------------------------
our @noActPsvFeeProds = (
		"NEX" , "NEX_LL" , "T_DEBT" , "T_DEBT_LL" , "T_EXCH" , "T_HI_CLOB_CORR" , "T_HI_MGF" , "T_HI_MGF_CORR" , 
		"T_HI_MGF_INTL" , "T_HI_OL" , "T_LO_CLOB_CORR" , "T_LO_MGF" , "T_LO_MGF_CORR" , "T_LO_OL" , "T_MBF" , 
		"T_MOC" , "T_HI_MOC" , "T_LO_MOC" , "T_MOO" , "T_HI_MOO" , "T_LO_MOO" , "T_MOO_CORR" , 
		"T_ST" , "V_EXT" , "V_EXT_CORR" , "V_HI_CLOB_CORR" , 
		"V_HI_OL_AUTOFILL" , "V_LO_CLOB_CORR" , "V_LO_T1_OL_AUTOFILL" , "V_LO_T2_OL_AUTOFILL" , "V_MOC" , "V_HI_MOC" ,
		"V_LO_MOC" , "V_MOO" , "V_HI_MOO" , "V_LO_MOO" , "V_MOO_CORR" , "V_MOO_DEBT" , "V_HI_MOO_DEBT" , "V_LO_MOO_DEBT" ,
		"T_HI_CMO" , "T_HI_CMO_UNINT_CROSS" , "T_HI_CMO_INTL" , "T_HI_CMO_UNINT_CROSS_INTL" ,
		"T_HI_ETF_CMO" , "T_HI_ETF_CMO_UNINT_CROSS" ,
		"T_LO_CMO" , "T_LO_CMO_UNINT_CROSS" ,
		"V_HI_CMO" , "V_HI_CMO_UNINT_CROSS" , "V_LO_CMO" , "V_LO_CMO_UNINT_CROSS"
	);

our %noActPsvFeeProds = map { $_ => 1 } @noActPsvFeeProds;

1;
