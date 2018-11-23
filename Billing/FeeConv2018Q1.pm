package FeeConv;

our %rateMap = ( 
	OLD => {

		T_HI_RT						=> { ACT => 0.0015 , PSV => -0.0019 } , 
		T_HI_RT_LL					=> { PSV => -0.0019 } ,
		T_HI_RT_PS					=> { PSV => -0.0019 } ,
		T_HI_RT_INTL				=> { ACT => 0.0027 , PSV => -0.0030 } , 				
		T_HI_RT_INTL_LL				=> { PSV => -0.0030 } ,
		T_HI_RT_INTL_PS				=> { PSV => -0.0030 } ,
	} ,
	
	NEW => {

#		--- Collapse targets ---
		T_HI_ETF_RT					=> { ACT => 0.0015 , PSV => -0.0021 } ,
		T_LO_ETF_RT					=> { ACT => 0.0000 , PSV => -0.00005 } ,
		T_HI_RT						=> { ACT => 0.0015 , PSV => -0.0013 } , # --- TIER A ---
		T_HI_RT_INTL				=> { ACT => 0.0027 , PSV => -0.0025 } , # --- TIER A ---
		T_LO_RT						=> { ACT => 0.0000 , PSV => -0.00005 } ,

#		--- Rights/Warrants collapse targets ---
		T_HI_CLOB					=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_LL				=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_PS				=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_LO_CLOB_T1_REG			=> { PSV => 0.000025 } ,
		T_LO_CLOB_T1_REG_LL			=> { PSV => 0.000025 } ,
		T_LO_CLOB_T1_REG_PS			=> { PSV => 0.000025 } ,
		T_LO_CLOB_T2_REG			=> { PSV => 0.000075 } ,
		T_LO_CLOB_T2_REG_LL			=> { PSV => 0.000075 } ,
		T_LO_CLOB_T2_REG_PS			=> { PSV => 0.000075 } ,
		
#		--- PRO RT collapse targets ---
		T_HI_CLOB_INTL				=> { ACT => 0.0027 , PSV => -0.0023 } ,
		T_HI_CLOB_INTL_LL			=> { PSV => -0.0023 } ,
		T_HI_CLOB_INTL_PS			=> { PSV => -0.0023 } ,
		T_HI_MOO					=> { ACT => 0.0030 } ,
		T_LO_MOO					=> { ACT => 0.0030 } ,
		T_HI_MOC					=> { ACT => 0.0025 } ,
		T_LO_MOC					=> { ACT => 0.0002 }
	}	
);

my @toastProds = ();
our %toastMap = map { $_ => 1 } @toastProds;

our %collapseMap = (
	NEW => {
		T_HI_ETF_RT				=> [ qw ( T_HI_ETF_RT_MGF T_HI_ETF_RT_PART ) ] ,
		T_HI_RT					=> [ qw ( T_HI_RT_MGF T_HI_RT_PART ) ] ,
		T_HI_RT_INTL			=> [ qw ( T_HI_RT_MGF_INTL T_HI_RT_PART_INTL ) ] ,
		T_LO_RT					=> [ qw ( T_LO_RT_MGF T_LO_RT_PART ) ]
	}
);

our %rtwtCollapseMap = (
	NEW => {
		T_HI_CLOB				=> [ qw ( T_HI_CLOB_ICE ) ] ,
		T_HI_CLOB_LL			=> [ qw ( T_HI_CLOB_ICE_LL ) ] ,
		T_HI_CLOB_PS			=> [ qw ( T_HI_CLOB_ICE_PS ) ] ,
		T_LO_CLOB_T1_REG		=> [ qw ( T_LO_CLOB_ICE_T1 ) ] ,
		T_LO_CLOB_T1_REG_LL		=> [ qw ( T_LO_CLOB_ICE_T1_LL ) ] ,
		T_LO_CLOB_T1_REG_PS		=> [ qw ( T_LO_CLOB_ICE_T1_PS ) ] ,
		T_LO_CLOB_T2_REG		=> [ qw ( T_LO_CLOB_ICE_T2 ) ] ,
		T_LO_CLOB_T2_REG_LL		=> [ qw ( T_LO_CLOB_ICE_T2_LL ) ] ,
		T_LO_CLOB_T2_REG_PS		=> [ qw ( T_LO_CLOB_ICE_T2_PS ) ] ,
	}
);
	
our %proCollapseMap = (
	NEW => {
		T_HI_CLOB				=> [ qw ( T_HI_RT T_HI_RT_OL T_HI_MOO_RT ) ] ,
		T_HI_CLOB_LL			=> [ qw ( T_HI_RT_LL ) ] ,
		T_HI_CLOB_PS			=> [ qw ( T_HI_RT_PS ) ] ,
		T_HI_CLOB_INTL			=> [ qw ( T_HI_RT_INTL ) ] ,
		T_HI_CLOB_INTL_LL		=> [ qw ( T_HI_RT_INTL_LL ) ] ,
		T_HI_CLOB_INTL_PS		=> [ qw ( T_HI_RT_INTL_PS ) ] ,
		T_LO_CLOB_T1_REG		=> [ qw ( T_LO_RT T_LO_RT_OL T_LO_MOO_RT ) ] , # --- this may need to be post-processed to T2 ---
		T_LO_CLOB_T1_REG_PS		=> [ qw ( T_LO_RT_PS ) ] , # --- this may need to be post-processed to T2 ---
		T_HI_MOC				=> [ qw ( T_HI_MOC_RT ) ] ,
		T_LO_MOC				=> [ qw ( T_LO_MOC_RT ) ] 
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
		"V_LO_MOC" , "V_MOO" , "V_HI_MOO" , "V_LO_MOO" , "V_MOO_CORR" , "V_MOO_DEBT" , "V_HI_MOO_DEBT" , "V_LO_MOO_DEBT"
	);

our %noActPsvFeeProds = map { $_ => 1 } @noActPsvFeeProds;

1;
