package FeeConv;

our %rateMap = ( 
	OLD => {
	
#		--- November 1 changes ---		
		T_LO_CLOB_ICE_T1			=> { PSV => 0.000025 } ,
		T_LO_CLOB_ICE_T1_PS			=> { PSV => 0.000025 } ,
		T_LO_CLOB_ICE_T1_LL			=> { PSV => 0.000025 } ,
		T_LO_CLOB_ICE_T2			=> { PSV => 0.000075 } ,
		T_LO_CLOB_ICE_T2_PS			=> { PSV => 0.000075 } ,
		T_LO_CLOB_ICE_T2_LL			=> { PSV => 0.000075 } ,
		T_HI_MOC					=> { ACT => 0.0030 , CAP => 30.00 } ,
		T_LO_MOC					=> { ACT => 0.0030 , CAP => 30.00 } ,
		T_HI_LIT_DARK				=> { ACT => 0.0010 , PSV => 0.0000 } ,
		T_HI_LIT_DARK_INTL			=> { ACT => 0.0010 , PSV => 0.0000 } ,
		T_HI_LIT_DARK_ETF			=> { ACT => 0.0010 , PSV => 0.0000 } ,
		T_HI_LIT_DARK_ETF_INTL		=> { ACT => 0.0010 , PSV => 0.0000 } ,
		T_LO_DARK_DARK_T1			=> { ACT => 0.000025 , PSV => 0.000025 } ,
		T_LO_LIT_DARK_T1			=> { ACT => 0.000025 , PSV => 0.000025 } ,
		T_LO_DARK_DARK_T2			=> { ACT => 0.000075 , PSV => 0.000075 } ,
		T_LO_LIT_DARK_T2			=> { ACT => 0.000075 , PSV => 0.000075 } ,
		V_LO_CLOB_ICE_T1			=> { PSV => 0.000025 } ,
		V_LO_CLOB_ICE_T1_LL			=> { PSV => 0.000025 } ,
		V_LO_CLOB_ICE_T1_PS			=> { PSV => 0.000025 } ,
		V_LO_DEBT_ICE_T1			=> { PSV => 0.000025 } ,
		V_LO_DEBT_ICE_T1_PS			=> { PSV => 0.000025 } ,
		V_LO_DEBT_ICE_T1_LL			=> { PSV => 0.000025 } ,
		V_LO_CLOB_ICE_T2			=> { PSV => 0.000075 } ,
		V_LO_CLOB_ICE_T2_PS			=> { PSV => 0.000075 } ,
		V_LO_CLOB_ICE_T2_LL			=> { PSV => 0.000075 } ,
		V_LO_DEBT_ICE_T2			=> { PSV => 0.000075 } ,
		V_LO_DEBT_ICE_T2_PS			=> { PSV => 0.000075 } ,
		V_LO_DEBT_ICE_T2_LL			=> { PSV => 0.000075 } ,
		V_HI_LIT_DARK				=> { ACT => 0.0010 , PSV => 0.0000 } ,
		V_LO_DARK_DARK_T1			=> { ACT => 0.000025 , PSV => 0.000025 } ,
		V_LO_LIT_DARK_T1			=> { ACT => 0.000025 , PSV => 0.000025 } ,
		V_LO_DARK_DARK_T2			=> { ACT => 0.000075 , PSV => 0.000075 } ,
		V_LO_LIT_DARK_T2			=> { ACT => 0.000075 , PSV => 0.000075 } ,
		V_HI_MOC					=> { ACT => 0.0012 , CAP => 60.00 } ,
		V_LO_MOC					=> { ACT => 0.0012 , CAP => 60.00 } ,

#		---October 1 changes ---
		T_HI_CLOB_ETF				=> { ACT => 0.0015 , PSV => -0.0011 } ,	
		T_HI_CLOB_ETF_JIT			=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_ETF_INTL			=> { ACT => 0.0015 , PSV => -0.0011 } ,
		T_HI_CLOB_ETF_JIT_INTL		=> { ACT => 0.0015 , PSV => -0.0011 } ,	
		T_HI_CLOB_ETF_LL			=> { PSV => -0.0011 } ,					
		T_HI_CLOB_ETF_INTL_LL		=> { PSV => -0.0011 } ,					
		T_HI_CLOB_ETF_JIT_LL		=> { PSV => -0.0011 } ,					
		T_HI_CLOB_ETF_JIT_INTL_LL	=> { PSV => -0.0011 } ,					
		T_HI_CLOB_ETF_PS			=> { PSV => -0.0011 } ,
		T_HI_CLOB_ETF_JIT_PS		=> { PSV => -0.0011 } ,
		T_HI_CLOB_ETF_INTL_PS		=> { PSV => -0.0011 } ,
		T_HI_CLOB_ETF_JIT_INTL_PS	=> { PSV => -0.0011 } ,
		T_HI_ETF_RT_PS				=> { PSV => -0.0019 } ,
		T_HI_ETF_RT_INTL_PS			=> { PSV => -0.0019 } ,

		T_HI_DARK_LIT_ETF			=> { ACT => 0.0015 } ,					
		T_HI_DARK_LIT_ETF_INTL		=> { ACT => 0.0015 } ,					

		T_HI_ETF_RT					=> { ACT => 0.0015 , PSV => -0.0019 } , 
		T_HI_ETF_RT_INTL			=> { ACT => 0.0015 , PSV => -0.0019 } ,	
		T_HI_ETF_RT_LL				=> { PSV => -0.0019 } ,					
		T_HI_ETF_RT_INTL_LL			=> { PSV => -0.0019 } ,					

	} ,
	NEW => {

#		--- Collapse targets ---
		T_HI_DARK_DARK				=> { ACT => 0.0010 , PSV => 0.0000 } ,
		V_HI_DARK_DARK				=> { ACT => 0.0010 , PSV => 0.0000 } ,
		
#		--- November 1 changes ---		
		T_LO_CLOB_ICE_T1			=> { PSV => 0.0000 } ,
		T_LO_CLOB_ICE_T1_PS			=> { PSV => 0.0000 } ,
		T_LO_CLOB_ICE_T1_LL			=> { PSV => 0.0000 } ,
		T_LO_CLOB_ICE_T2			=> { PSV => 0.0000 } ,
		T_LO_CLOB_ICE_T2_PS			=> { PSV => 0.0000 } ,
		T_LO_CLOB_ICE_T2_LL			=> { PSV => 0.0000 } ,
		T_HI_MOC					=> { ACT => 0.0025 , CAP => 25.00 } ,
		T_LO_MOC					=> { ACT => 0.0002 , CAP => 25.00 } ,
		T_HI_LIT_DARK				=> { ACT => 0.0015 , PSV => 0.0000 } ,
		T_HI_LIT_DARK_INTL			=> { ACT => 0.0027 , PSV => 0.0000 } ,
		T_HI_LIT_DARK_ETF			=> { ACT => 0.0015 , PSV => 0.0000 } ,
		T_HI_LIT_DARK_ETF_INTL		=> { ACT => 0.0015 , PSV => 0.0000 } ,
		T_LO_DARK_DARK_T1			=> { ACT => 0.000025 , PSV => 0.0000 } ,
		T_LO_LIT_DARK_T1			=> { ACT => 0.000025 , PSV => 0.0000 } ,
		T_LO_DARK_DARK_T2			=> { ACT => 0.000075 , PSV => 0.0000 } ,
		T_LO_LIT_DARK_T2			=> { ACT => 0.000075 , PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T1			=> { PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T1_LL			=> { PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T1_PS			=> { PSV => 0.0000 } ,
		V_LO_DEBT_ICE_T1			=> { PSV => 0.0000 } ,
		V_LO_DEBT_ICE_T1_PS			=> { PSV => 0.0000 } ,
		V_LO_DEBT_ICE_T1_LL			=> { PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T2			=> { PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T2_PS			=> { PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T2_LL			=> { PSV => 0.0000 } ,
		V_LO_DEBT_ICE_T2			=> { PSV => 0.0000 } ,
		V_LO_DEBT_ICE_T2_PS			=> { PSV => 0.0000 } ,
		V_LO_DEBT_ICE_T2_LL			=> { PSV => 0.0000 } ,
		V_HI_LIT_DARK				=> { ACT => 0.0015 , PSV => 0.0000 } ,
		V_LO_LIT_DARK_T1			=> { ACT => 0.000025 , PSV => 0.0000 } ,
		V_LO_DARK_DARK_T1			=> { ACT => 0.000025 , PSV => 0.0000 } ,
		V_LO_LIT_DARK_T2			=> { ACT => 0.000075 , PSV => 0.0000 } ,
		V_LO_DARK_DARK_T2			=> { ACT => 0.000075 , PSV => 0.0000 } ,
		V_HI_MOC					=> { ACT => 0.0025 , CAP => 25.00 } ,
		V_LO_MOC					=> { ACT => 0.0002 , CAP => 25.00 } ,

#		---October 1 changes ---
		T_HI_CLOB_ETF_PS			=> { PSV => -0.0013 } ,
		T_HI_CLOB_ETF_JIT_PS		=> { PSV => -0.0013 } ,
		T_HI_CLOB_ETF_INTL_PS		=> { PSV => -0.0013 } ,
		T_HI_CLOB_ETF_JIT_INTL_PS	=> { PSV => -0.0013 } ,
		T_HI_ETF_RT_PS				=> { PSV => -0.0021 } ,
		T_HI_ETF_RT_INTL_PS			=> { PSV => -0.0021 } ,

		T_HI_CLOB_ETF				=> { ACT => 0.0017 , PSV => -0.0013 } ,	
		T_HI_CLOB_ETF_JIT			=> { ACT => 0.0017 , PSV => -0.0013 } ,	
		T_HI_CLOB_ETF_INTL			=> { ACT => 0.0017 , PSV => -0.0013 } ,	
		T_HI_CLOB_ETF_JIT_INTL		=> { ACT => 0.0017 , PSV => -0.0013 } ,
		T_HI_CLOB_ETF_LL			=> { PSV => -0.0013 } ,					
		T_HI_CLOB_ETF_INTL_LL		=> { PSV => -0.0013 } ,				
		T_HI_CLOB_ETF_JIT_LL		=> { PSV => -0.0013 } ,					
		T_HI_CLOB_ETF_JIT_INTL_LL	=> { PSV => -0.0013 } ,					
		
		T_HI_DARK_LIT_ETF			=> { ACT => 0.0017 } ,					
		T_HI_DARK_LIT_ETF_INTL		=> { ACT => 0.0017 } ,					
		
		T_HI_ETF_RT					=> { ACT => 0.0017 , PSV => -0.0021 } ,
		T_HI_ETF_RT_INTL			=> { ACT => 0.0017 , PSV => -0.0021 } ,
		T_HI_ETF_RT_LL				=> { PSV => -0.0021 } ,					
		T_HI_ETF_RT_INTL_LL			=> { PSV => -0.0021 } ,					
	}
);

my @toastProds = ();
our %toastMap = map { $_ => 1 } @toastProds;

our %collapseMap = (
	NEW => {
		T_HI_DARK_DARK			=> [ qw ( T_HI_DARK_DARK_ETF T_HI_DARK_DARK_INTL T_HI_PEG_IOC_DARK T_HI_PEG_IOC_DARK_INTL T_HI_PEG_IOC_DARK_ETF T_HI_PEG_IOC_DARK_ETF_INTL ) ] ,
		T_LO_DARK_DARK_T1		=> [ qw ( T_LO_PEG_IOC_DARK_T1 ) ] ,
		T_LO_DARK_DARK_T2		=> [ qw ( T_LO_PEG_IOC_DARK_T2 ) ] ,
		T_HI_LIT_DARK			=> [ qw ( T_HI_LIT_DARK_ETF T_HI_LIT_DARK_INTL ) ] ,
		V_HI_DARK_DARK			=> [ qw ( V_HI_PEG_IOC_DARK ) ] ,
		V_LO_DARK_DARK_T1		=> [ qw ( V_LO_PEG_IOC_DARK_T1 ) ] ,
		V_LO_DARK_DARK_T2		=> [ qw ( V_LO_PEG_IOC_DARK_T2 ) ] ,
		
		T_MOO					=> [ qw ( T_HI_MOO T_LO_MOO ) ] ,
		T_MOO_RT				=> [ qw ( T_HI_MOO_RT T_LO_MOO_RT ) ] ,
		V_MOO					=> [ qw ( V_HI_MOO V_LO_MOO ) ] ,
		V_MOO_DEBT				=> [ qw ( V_HI_MOO_DEBT V_LO_MOO_DEBT ) ] 
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
