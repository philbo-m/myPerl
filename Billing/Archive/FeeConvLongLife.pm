package FeeConvLongLife;

our %feeMap = ( 
	OLD => {
		T_DEBT					=> { ACT => 0.0001 , PSV => 0.0001 } ,
		T_DEBT_RT				=> { ACT => 0.0000 , PSV => 0.0000 } ,
		T_EXCH					=> { ACT => 2.0000 , PSV => 2.0000 } ,
		T_EXCH_RT				=> { ACT => 0.0000 , PSV => 0.0000 } ,
		T_ST					=> { ACT => 0.0010 , PSV => 0.0010 } ,
		T_HI_CLOB_ETF			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_INTL		=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_ICE_INTL	=> { PSV => 0.0000 } ,
		T_HI_CLOB_ETF_JIT		=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_JIT_INTL	=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ICE_INTL		=> { PSV => 0.0000 } ,
		T_HI_CLOB_ICE			=> { PSV => 0.0000 } ,
		T_HI_CLOB_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_JIT_INTL		=> { ACT => 0.0030 , PSV => -0.0026 } ,
		T_HI_CLOB_INTL			=> { ACT => 0.0030 , PSV => -0.0026 } ,
		T_HI_CLOB				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_ETF_RT				=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_HI_ETF_RT_INTL		=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_HI_RT_INTL			=> { ACT => 0.0030 , PSV => -0.0030 } ,
		T_HI_RT					=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_LO_CLOB_T1_REG		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		T_LO_CLOB_ICE_T1		=> { PSV => 0.00025 } ,
		T_LO_CLOB_JITNEY_T1		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		T_LO_CLOB_T2_REG		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		T_LO_CLOB_ICE_T2		=> { PSV => 0.00075 } ,
		T_LO_CLOB_JITNEY_T2		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		T_LO_ETF_RT				=> { ACT => 0.0002 , PSV => -0.0001 } ,
		T_LO_RT					=> { ACT => 0.0000 , PSV => -0.0005 } ,
		T_RW					=> { ACT => 0.00025 , PSV => 0.00000 } ,
		T_RW_RT					=> { ACT => 0.00000 , PSV => 0.00000 } ,
		NEX						=> { ACT => 0.0005 , PSV => 0.0005 } ,
		NEX_VOD					=> { ACT => 0.0000 , PSV => 0.0000 } ,
		V_HI_CLOB_ICE			=> { PSV => 0.0000 } ,
		V_HI_CLOB_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_CLOB				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT_ICE			=> { PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T1		=> { PSV => 0.00025 } ,
		V_LO_CLOB_JIT_T1		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_CLOB_ICE_T2		=> { PSV => 0.00075 } ,
		V_LO_CLOB_JIT_T2		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_LO_CLOB_T1_REG		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_CLOB_T2_REG		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_LO_DEBT_T1			=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_DEBT_T1_ICE		=> { PSV => 0.00025 } ,
		V_LO_DEBT_T1_JIT		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_DEBT_T2			=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_LO_DEBT_T2_ICE		=> { PSV => 0.00075 } ,
		V_LO_DEBT_T2_JIT		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_HI_VOD				=> { ACT => 0.0023 , PSV => -0.0027 } ,
		V_LO_VOD				=> { ACT => 0.00000 , PSV => -0.00005 }
	} , 
	NEW => {
		T_DEBT					=> { ACT => 0.0001 , PSV => 0.0001 } ,
		T_DEBT_RT				=> { ACT => 0.0000 , PSV => 0.0000 } ,
		T_EXCH					=> { ACT => 2.0000 , PSV => 2.0000 } ,
		T_EXCH_RT				=> { ACT => 0.0000 , PSV => 0.0000 } ,
		T_ST					=> { ACT => 0.0010 , PSV => 0.0010 } ,
		T_HI_CLOB_ETF			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_INTL		=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_ICE_INTL	=> { PSV => 0.0000 } ,
		T_HI_CLOB_ETF_JIT		=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ETF_JIT_INTL	=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_ICE_INTL		=> { PSV => 0.0000 } ,
		T_HI_CLOB_ICE			=> { PSV => 0.0000 } ,
		T_HI_CLOB_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_CLOB_JIT_INTL		=> { ACT => 0.0030 , PSV => -0.0026 } ,
		T_HI_CLOB_INTL			=> { ACT => 0.0030 , PSV => -0.0026 } ,
		T_HI_CLOB				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		T_HI_ETF_RT				=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_HI_ETF_RT_INTL		=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_HI_RT_INTL			=> { ACT => 0.0030 , PSV => -0.0030 } ,
		T_HI_RT					=> { ACT => 0.0023 , PSV => -0.0027 } ,
		T_LO_CLOB_T1_REG		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		T_LO_CLOB_ICE_T1		=> { PSV => 0.00025 } ,
		T_LO_CLOB_JITNEY_T1		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		T_LO_CLOB_T2_REG		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		T_LO_CLOB_ICE_T2		=> { PSV => 0.00075 } ,
		T_LO_CLOB_JITNEY_T2		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		T_LO_ETF_RT				=> { ACT => 0.0002 , PSV => -0.0001 } ,
		T_LO_RT					=> { ACT => 0.0000 , PSV => -0.0005 } ,
		T_RW					=> { ACT => 0.00025 , PSV => 0.00000 } ,
		T_RW_RT					=> { ACT => 0.00000 , PSV => 0.00000 } ,
		NEX						=> { ACT => 0.0005 , PSV => 0.0005 } ,
		NEX_VOD					=> { ACT => 0.0000 , PSV => 0.0000 } ,
		V_HI_CLOB_ICE			=> { PSV => 0.0000 } ,
		V_HI_CLOB_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_CLOB				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT				=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT_JIT			=> { ACT => 0.0023 , PSV => -0.0019 } ,
		V_HI_DEBT_ICE			=> { PSV => 0.0000 } ,
		V_LO_CLOB_ICE_T1		=> { PSV => 0.00025 } ,
		V_LO_CLOB_JIT_T1		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_CLOB_ICE_T2		=> { PSV => 0.00075 } ,
		V_LO_CLOB_JIT_T2		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_LO_CLOB_T1_REG		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_CLOB_T2_REG		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_LO_DEBT_T1			=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_DEBT_T1_ICE		=> { PSV => 0.00025 } ,
		V_LO_DEBT_T1_JIT		=> { ACT => 0.00025 , PSV => 0.00025 } ,
		V_LO_DEBT_T2			=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_LO_DEBT_T2_ICE		=> { PSV => 0.00075 } ,
		V_LO_DEBT_T2_JIT		=> { ACT => 0.00075 , PSV => 0.00075 } ,
		V_HI_VOD				=> { ACT => 0.0023 , PSV => -0.0027 } ,
		V_LO_VOD				=> { ACT => 0.00000 , PSV => -0.00005 }
	}
);

our %collapseMap = (
	NEW => {
		NEX						=> [ "NEX_LL" ] ,
		NEX_VOD					=> [ "NEX_VOD_LL" ] ,
		T_DEBT					=> [ "T_DEBT_LL" ] ,
		T_DEBT_RT				=> [ "T_DEBT_RT_LL" ] ,
		T_EXCH					=> [ "T_EXCH_LL" ] ,
		T_EXCH_RT				=> [ "T_EXCH_RT_LL" ] ,
		T_HI_CLOB				=> [ "T_HI_CLOB_LL" ] ,
		T_HI_CLOB_ETF			=> [ "T_HI_CLOB_ETF_LL" ] ,
		T_HI_CLOB_ETF_ICE		=> [ "T_HI_CLOB_ETF_ICE_LL" ] ,
		T_HI_CLOB_ETF_ICE_INTL	=> [ "T_HI_CLOB_ETF_ICE_INTL_LL" ] ,
		T_HI_CLOB_ETF_INTL		=> [ "T_HI_CLOB_ETF_INTL_LL" ] ,
		T_HI_CLOB_ETF_JIT		=> [ "T_HI_CLOB_ETF_JIT_LL" ] ,
		T_HI_CLOB_ETF_JIT_INTL	=> [ "T_HI_CLOB_ETF_JIT_INTL_LL" ] ,
		T_HI_CLOB_ICE			=> [ "T_HI_CLOB_ICE_LL" ] ,
		T_HI_CLOB_ICE_INTL		=> [ "T_HI_CLOB_ICE_INTL_LL" ] ,
		T_HI_CLOB_JIT			=> [ "T_HI_CLOB_JIT_LL" ] ,
		T_HI_CLOB_JIT_INTL		=> [ "T_HI_CLOB_JIT_INTL_LL" ] ,
		T_HI_CLOB_INTL			=> [ "T_HI_CLOB_INTL_LL" ] ,
		T_HI_ETF_RT				=> [ "T_HI_ETF_RT_LL" ] ,
		T_HI_ETF_RT_INTL		=> [ "T_HI_ETF_RT_INTL_LL" ] ,
		T_HI_RT					=> [ "T_HI_RT_LL" ] ,
		T_HI_RT_INTL			=> [ "T_HI_RT_INTL_LL" ] ,
		T_LO_CLOB_ICE_T1		=> [ "T_LO_CLOB_ICE_T1_LL" ] ,
		T_LO_CLOB_ICE_T2		=> [ "T_LO_CLOB_ICE_T2_LL" ] ,
		T_LO_CLOB_JITNEY_T1		=> [ "T_LO_CLOB_JITNEY_T1_LL" ] ,
		T_LO_CLOB_JITNEY_T2		=> [ "T_LO_CLOB_JITNEY_T2_LL" ] ,
		T_LO_CLOB_T1_REG		=> [ "T_LO_CLOB_T1_REG_LL" ] ,
		T_LO_CLOB_T2_REG		=> [ "T_LO_CLOB_T2_REG_LL" ] ,
		T_LO_ETF_RT				=> [ "T_LO_ETF_RT_LL" ] ,
		T_LO_RT					=> [ "T_LO_RT_LL" ] ,
		T_RW					=> [ "T_RW_LL" ] ,
		T_RW_RT					=> [ "T_RW_RT_LL" ] ,
		T_ST					=> [ "T_ST_LL" ] ,
		V_HI_CLOB				=> [ "V_HI_CLOB_LL" ] ,
		V_HI_CLOB_ICE			=> [ "V_HI_CLOB_ICE_LL" ] ,
		V_HI_CLOB_JIT			=> [ "V_HI_CLOB_JIT_LL" ] ,
		V_HI_DEBT				=> [ "V_HI_DEBT_LL" ] ,
		V_HI_DEBT_ICE			=> [ "V_HI_DEBT_ICE_LL" ] ,
		V_HI_DEBT_JIT			=> [ "V_HI_DEBT_JIT_LL" ] ,
		V_HI_VOD				=> [ "V_HI_VOD_LL" ] ,
		V_LO_CLOB_ICE_T1		=> [ "V_LO_CLOB_ICE_T1_LL" ] ,
		V_LO_CLOB_ICE_T2		=> [ "V_LO_CLOB_ICE_T2_LL" ] ,
		V_LO_CLOB_JIT_T1		=> [ "V_LO_CLOB_JIT_T1_LL" ] ,
		V_LO_CLOB_JIT_T2		=> [ "V_LO_CLOB_JIT_T2_LL" ] ,
		V_LO_CLOB_T1_REG		=> [ "V_LO_CLOB_T1_REG_LL" ] ,
		V_LO_CLOB_T2_REG		=> [ "V_LO_CLOB_T2_REG_LL" ] ,
		V_LO_DEBT_ICE_T1		=> [ "V_LO_DEBT_ICE_T1_LL" ] ,
		V_LO_DEBT_ICE_T2		=> [ "V_LO_DEBT_ICE_T2_LL" ] ,
		V_LO_DEBT_JIT_T1		=> [ "V_LO_DEBT_JIT_T1_LL" ] ,
		V_LO_DEBT_JIT_T2		=> [ "V_LO_DEBT_JIT_T2_LL" ] ,
		V_LO_DEBT_T1			=> [ "V_LO_DEBT_T1_LL" ] ,
		V_LO_DEBT_T2			=> [ "V_LO_DEBT_T2_LL" ] ,
		V_LO_VOD				=> [ "V_LO_VOD_LL" ]
	}
);

# Relevant sub-products whose Account Summ records' Active Fee/Passive Credit fields are zero
# -------------------------------------------------------------------------------------------
our @noActPsvFeeProds = (
		"NEX" , "T_DEBT" , "T_EXCH" , "T_EXT" , "T_EXT_CORR" , "T_HI_CLOB_CORR" , "T_HI_MGF" , "T_HI_MGF_CORR" , 
		"T_HI_MGF_INTL" , "T_HI_OL" , "T_LO_CLOB_CORR" , "T_LO_MGF" , "T_LO_MGF_CORR" , "T_LO_OL" , "T_MBF" , 
		"T_MOC" , "T_MOO" , "T_MOO_CORR" , "T_RW_CPF_OPN" , "T_ST" , "V_EXT" , "V_EXT_CORR" , "V_HI_CLOB_CORR" , 
		"V_HI_OL_AUTOFILL" , "V_LO_CLOB_CORR" , "V_LO_T1_OL_AUTOFILL" , "V_LO_T2_OL_AUTOFILL" , "V_MOC" , 
		"V_MOO" , "V_MOO_CORR" , "V_MOO_DEBT"
	);

our %noActPsvFeeProds = map { $_ => 1 } @noActPsvFeeProds;


1;