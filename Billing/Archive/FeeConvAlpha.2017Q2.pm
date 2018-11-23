package FeeConvAlpha;

our %feeMap = ( 
	OLD => {
		T_LO_CLOB					=> { ACT => -0.0006 , PSV => 0.0010 } ,
		T_LO_CLOB_ICE				=> { PSV => 0.0010 } ,
		T_LO_CLOB_ICE_POSTONLY		=> { PSV => 0.0012 } ,
		T_LO_CLOB_POSTONLY			=> { PSV => 0.0012 } ,
		T_LO_ETF_ICE_POSTONLY		=> { PSV => 0.0012 } ,
		T_LO_ETF_POSTONLY			=> { PSV => 0.0012 } ,
		T_LO_ETF					=> { ACT => -0.0006 , PSV => 0.0010 } ,
		T_LO_ETF_ICE				=> { PSV => 0.0010 } ,
		V_LO_CLOB					=> { ACT => -0.0006 , PSV => 0.0010 } ,
		V_LO_CLOB_ICE				=> { PSV => 0.0010 } ,
		V_LO_CLOB_ICE_POSTONLY		=> { PSV => 0.0012 } ,
		V_LO_CLOB_POSTONLY			=> { PSV => 0.0012 } ,
	} , 
	NEW => {
		T_LO_CLOB					=> { ACT => -0.0010 , PSV => 0.0014 } ,
		T_LO_CLOB_ICE				=> { PSV => 0.0014 } ,
		T_LO_CLOB_ICE_POSTONLY		=> { PSV => 0.0016 } ,
		T_LO_CLOB_POSTONLY			=> { PSV => 0.0016 } ,
		T_LO_ETF_ICE_POSTONLY		=> { PSV => 0.0016 } ,
		T_LO_ETF_POSTONLY			=> { PSV => 0.0016 } ,
		T_LO_ETF					=> { ACT => -0.0010 , PSV => 0.0014 } ,
		T_LO_ETF_ICE				=> { PSV => 0.0014 } ,
		V_LO_CLOB					=> { ACT => -0.0010 , PSV => 0.0014 } ,
		V_LO_CLOB_ICE				=> { PSV => 0.0014 } ,
		V_LO_CLOB_ICE_POSTONLY		=> { PSV => 0.0016 } ,
		V_LO_CLOB_POSTONLY			=> { PSV => 0.0016 } ,
	}
);
	
our %collapseMap = (
	OLD => {
	} ,
	NEW => {
	}
);

1;
