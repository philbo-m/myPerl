package FeeConv;

our %feeMap = ( 
	OLD => {
		T_HI_LIT_DARK			=> { ACT => 0.0010 , PSV => 0.0000 } ,
		T_HI_DARK_DARK			=> { ACT => 0.0010 , PSV => 0.0000 } ,
	} , 
	
	NEW => {
		T_HI_LIT_DARK			=> { ACT => 0.0010 , PSV => 0.0000 } ,
		T_HI_DARK_DARK			=> { ACT => 0.0010 , PSV => 0.0000 } ,
	}
);

my @toastProds = ();
our %toastMap = map { $_ => 1 } @toastProds;

our %collapseMap = (
	NEW => {
		T_HI_DARK_DARK			=> [ qw ( T_HI_DARK_DARK_ETF T_HI_DARK_DARK_INTL ) ] ,
		T_HI_LIT_DARK			=> [ qw ( T_HI_LIT_DARK_ETF T_HI_LIT_DARK_INTL ) ]
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
