package AlphaProdMap;

our %subProdMap = (

	"TSX High CLOB"			=> [ "T_HI_T1_CLOB" , "T_HI_T1_CLOB_POSTONLY" , "T_HI_T1_CLOB_ICE" , "T_HI_T1_CLOB_ICE_POSTONLY" , 
								"T_HI_T2_CLOB" , "T_HI_T2_CLOB_POSTONLY" , "T_HI_T2_CLOB_ICE" , "T_HI_T2_CLOB_ICE_POSTONLY" ,
								"T_HI_T1_CLOB_JIT" , "T_HI_T2_CLOB_JIT" ] ,
	"TSX Low CLOB"			=> [ "T_LO_CLOB" , "T_LO_CLOB_POSTONLY" , "T_LO_CLOB_ICE" , "T_LO_CLOB_ICE_POSTONLY" ,
								"T_LO_T1_CLOB" , "T_LO_T1_CLOB_ICE" , "T_LO_T1_CLOB_JIT" ,
								"T_LO_T2_CLOB" , "T_LO_T2_CLOB_ICE" , "T_LO_T2_CLOB_JIT" ] ,
	"TSX Opening Auction"	=> [ "T_HI_T1_MOO" , "T_HI_T1_ETF_MOO" , "T_HI_T2_MOO" , "T_HI_T2_ETF_MOO" , "T_LO_MOO" , 
								"T_LO_ETF_MOO" , "T_MOO_CORR" ,
								"T_LO_T1_MOO" , "T_LO_T2_MOO" ] ,
	"TSX High ETF"			=> [ "T_HI_T1_ETF" , "T_HI_T1_ETF_POSTONLY" , "T_HI_T1_ETF_ICE" , "T_HI_T1_ETF_ICE_POSTONLY" ,
								"T_HI_T2_ETF" , "T_HI_T2_ETF_POSTONLY" , "T_HI_T2_ETF_ICE" , "T_HI_T2_ETF_ICE_POSTONLY" ,
								"T_HI_T1_ETF_JIT" , "T_HI_T2_ETF_JIT" ] ,
	"TSX Low ETF"			=> [ "T_LO_ETF" , "T_LO_ETF_POSTONLY" , "T_LO_ETF_ICE" , "T_LO_ETF_ICE_POSTONLY" ] ,
	"TSX Special Cross"		=> [ "T_SPC" ] ,
	"TSX Correction"		=> [ "T_CORR" ] ,
	"TSX Cross Printing"	=> [ "T_CPF" , "T_CPF_CORR" ] ,
	"TSX Self Trade"		=> [ "T_SELF_TRADE" ] ,
	"TSX Debt/Notes"		=> [ "T_DEBT" , "T_DEBT_ICE" ,
								"T_DEBT_JIT" ] ,
	"TSX AOD"				=> [ "T_HI_T1_AOD" , "T_HI_T1_AOD_ETF" , "T_HI_T2_AOD" , "T_HI_T2_AOD_ETF" , "T_LO_AOD" , 
								"T_LO_AOD_ETF" , "T_HI_T1_AOD_AUTOFILL" , "T_HI_T1_AOD_AUTOFILL_ETF" , "T_HI_T2_AOD_AUTOFILL" ,
								"T_HI_T2_AOD_AUTOFILL_ETF" , "T_LO_AOD_AUTOFILL" , "T_LO_AOD_AUTOFILL_ETF" ,
								"T_LO_T1_AOD" , "T_LO_T2_AOD" ] ,
	"TSX Oddlot Autofill"	=> [ "T_ODDLOT_AUTOFILL" , 	"T_ODDLOT_AUTOFILL_ETF" ] ,
	"TSXV High CLOB"		=> [ "V_HI_T1_CLOB" , "V_HI_T1_CLOB_POSTONLY" , "V_HI_T1_CLOB_ICE" , "V_HI_T1_CLOB_ICE_POSTONLY" , 
								"V_HI_T2_CLOB" , "V_HI_T2_CLOB_POSTONLY" , "V_HI_T2_CLOB_ICE" , "V_HI_T2_CLOB_ICE_POSTONLY" ,
								"V_HI_T1_CLOB_JIT" , "V_HI_T2_CLOB_JIT" ] ,
	"TSXV Low CLOB"			=> [ "V_LO_CLOB" , "V_LO_CLOB_POSTONLY" , "V_LO_CLOB_ICE" , "V_LO_CLOB_ICE_POSTONLY" ,
								"V_LO_T1_CLOB" , "V_LO_T1_CLOB_ICE" , "V_LO_T1_CLOB_JIT" ,
								"V_LO_T2_CLOB" , "V_LO_T2_CLOB_ICE" , "V_LO_T2_CLOB_JIT" ] ,
	"TSXV Opening Auction"	=> [ "V_HI_T1_MOO" , "V_HI_T2_MOO" , "V_LO_MOO" , "V_MOO_CORR" ,
								"V_LO_T1_MOO" , "V_LO_T2_MOO" ] ,
	"TSXV Cross Printing"	=> [ "V_CPF" , "V_CPF_CORR" ] ,
	"TSXV Special Cross"	=> [ "V_SPC" ] ,
	"TSXV Correction"		=> [ "V_CORR" ] ,
	"TSXV AOD"				=> [ "V_HI_T1_AOD" , "V_HI_T1_AOD_ODD" , "V_HI_T2_AOD" , "V_HI_T2_AOD_ODD" , "V_LO_AOD" , 
								"V_LO_AOD_AUTOFILL" ,
								"V_LO_T1_AOD_ODD" , "V_LO_T2_AOD_ODD" ] ,
	"TSXV Debt/Notes"		=> [ "V_DEBT" , "V_DEBT_ICE" ,
								"V_DEBT_JIT" ] ,
	"TSXV Self Trade"		=> [ "V_SELF_TRADE" ] ,
	"TSXV AOD Rebate"		=> [ "V_AOD_REBATE" ] ,
	"TSXV Oddlot Autofill"	=> [ "V_ODDLOT_AUTOFILL" ] ,
	
	"NEX Trading"			=> [ "NEX_HI_T1" , "NEX_HI_T2" , "NEX_LO_T1" , "NEX_LO_T2" ,
								"NEX_ODD_HI_T1" , "NEX_ODD_HI_T2" , "NEX_ODD_LO_T1" , "NEX_ODD_LO_T2" ] ,
	
	"TSX High Dark" 		=> [ "T_HI_T1_DARK_DARK" , "T_HI_T2_DARK_DARK" ] ,
	"TSX Low Dark"			=> [ "T_LO_T1_DARK_DARK" , "T_LO_T2_DARK_DARK" ] ,
	"TSX High SDL"			=> [ "T_HI_T1_SDL_LIT" , "T_HI_T2_SDL_LIT" , "T_HI_T1_SDL_DARK" , "T_HI_T2_SDL_DARK" ] ,
	"TSX Low SDL"			=> [ "T_LO_T1_SDL_LIT" , "T_LO_T2_SDL_LIT" , "T_LO_T1_SDL_DARK" , "T_LO_T2_SDL_DARK" ] ,
	"TSX High ETF Dark"		=> [ "T_HI_T1_ETF_DARK_DARK" , "T_HI_T2_ETF_DARK_DARK" ] ,
	"TSX High ETF SDL"		=> [ "T_HI_T1_ETF_SDL_LIT" , "T_HI_T1_ETF_SDL_DARK" , "T_HI_T2_ETF_SDL_LIT" , "T_HI_T2_ETF_SDL_DARK" ] ,
	"TSX Debt/Notes Dark"	=> [ "T_DEBT_DARK_DARK" ] ,
	"TSX Debt/Notes SDL"	=> [ "T_DEBT_SDL_LIT" , "T_DEBT_SDL_DARK" ] ,
	"TSXV High Dark"		=> [ "V_HI_T1_DARK_DARK" , "V_HI_T2_DARK_DARK" ] ,
	"TSXV Low Dark"			=> [ "V_LO_T1_DARK_DARK" , "V_LO_T2_DARK_DARK" ] ,
	"TSXV High SDL"			=> [ "V_HI_T1_SDL_LIT" , "V_HI_T2_SDL_LIT" , "V_HI_T1_SDL_DARK" , "V_HI_T2_SDL_DARK" ] ,
	"TSXV Low SDL"			=> [ "V_LO_T1_SDL_LIT" , "V_LO_T2_SDL_LIT" , "V_LO_T1_SDL_DARK" , "V_LO_T2_SDL_DARK" ] ,
	"TSXV Debt/Notes Dark"	=> [ "V_DEBT_DARK_DARK" ] ,
	"TSXV Debt/Notes SDL"	=> [ "V_DEBT_SDL_LIT" , "V_DEBT_SDL_DARK" ] ,

 );


1; 


