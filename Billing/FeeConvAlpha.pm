package FeeConvAlpha;

our %feeMap = ( 
	OLD => {
		T_HI_T1_ETF					=> { ACT => -0.0010 , PSV => 0.0014 } ,
		T_HI_T1_ETF_POSTONLY		=> { PSV => 0.0016 } ,
		T_HI_T1_ETF_ICE				=> { PSV => 0.0014 } ,
		T_HI_T1_ETF_ICE_POSTONLY	=> { PSV => 0.0016 } ,
		T_HI_T2_ETF					=> { ACT => -0.0010 , PSV => 0.0014 } ,
		T_HI_T2_ETF_POSTONLY		=> { PSV => 0.0016 } ,
		T_HI_T2_ETF_ICE				=> { PSV => 0.0014 } ,
		T_HI_T2_ETF_ICE_POSTONLY	=> { PSV => 0.0016 } ,
		T_LO_ETF					=> { ACT => -0.0010 , PSV => 0.0014 } ,
		T_LO_ETF_POSTONLY			=> { PSV => 0.0016 } ,
		T_LO_ETF_ICE				=> { PSV => 0.0014 } ,
		T_LO_ETF_ICE_POSTONLY		=> { PSV => 0.0016 } ,
	} ,
	NEW => {
		T_HI_T1_ETF					=> { ACT => -0.0010 , PSV => 0.0013 } ,
		T_HI_T1_ETF_POSTONLY		=> { PSV => 0.0014 } ,
		T_HI_T1_ETF_ICE				=> { PSV => 0.0013 } ,
		T_HI_T1_ETF_ICE_POSTONLY	=> { PSV => 0.0014 } ,
		T_HI_T2_ETF					=> { ACT => -0.0010 , PSV => 0.0013 } ,
		T_HI_T2_ETF_POSTONLY		=> { PSV => 0.0014 } ,
		T_HI_T2_ETF_ICE				=> { PSV => 0.0013 } ,
		T_HI_T2_ETF_ICE_POSTONLY	=> { PSV => 0.0014 } ,
		T_LO_ETF					=> { ACT => -0.0010 , PSV => 0.0013 } ,
		T_LO_ETF_POSTONLY			=> { PSV => 0.0014 } ,
		T_LO_ETF_ICE				=> { PSV => 0.0013 } ,
		T_LO_ETF_ICE_POSTONLY		=> { PSV => 0.0014 } ,
	}
);
	
our %collapseMap = (
	OLD => {
	} ,
	NEW => {
	}
);

1;
