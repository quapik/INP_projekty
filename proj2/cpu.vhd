-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2020 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Vojtech Sima, xsimav01
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WE    : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti 
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;
-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- signaly
	signal PC_registr : std_logic_vector(11 downto 0);  --jde do CODE ADDR (ROM) -> stejna velikost
	signal PC_inc		: std_logic;
	signal PC_dec		: std_logic;
	signal PC_ld		: std_logic;
	
	signal RAS_registr : std_logic_vector(11 downto 0); --stejne jakSo PC_registr
	
	signal PTR_registr : std_logic_vector(9 downto 0); --jde do DATA ADDR
	signal PTR_inc		: std_logic;
	signal PTR_dec		: std_logic; 
	
	type FSM_state is ( sPtr_dec,  sPTR_inc,  sVal_dec, sVal_dec2, sVal_inc, sVal_inc2, sWhile_begin, sWhile_begin2,sWhile_begin3,
 	sWhile_end, sPrint, sPrint2, sRead, sRead2, sStart, sFetch,sDecode, sNULL);
	
	signal Astate : FSM_state := sStart; --aktualni stav
	signal Nstate : FSM_state; --nasledujici
	
	signal MUXoutput :std_logic_vector (7 downto 0);  --do DATA_WDATA (RAM)
	signal MUXinput :std_logic_vector (1 downto 0); --ridici vstup, 2 bity
	
	

begin

-----------------PC
	PC: process(CLK,RESET, PC_inc, PC_dec, PC_ld) is
	begin
	
	if (RESET='1') then --pokud mame reset
		PC_registr<=(others=>'0');
	elsif (CLK'event) and (CLK ='1') then -- nabezna hrana 
		if (PC_dec='1') then --snizeni o 1
			PC_registr<=PC_registr-1;
		elsif (PC_inc='1') then --zvyseni o 1
			PC_registr<=PC_registr+1;
		elsif (PC_ld='1') then
		PC_registr<=RAS_registr;
		end if;	
	end if;	
	end process;
	CODE_ADDR<=PC_registr; --jde do ROM na OODE_ADDR
 ---------------PTR
	PTR: process (CLK, RESET, PTR_inc, PTR_dec) is
	begin
	
	if (RESET='1') then --pokud mame reset
		PTR_registr<=(others=>'0');
	elsif (CLK'event) and (CLK ='1') then -- nabezna hrana 
		if (PTR_dec='1') then --snizeni o 1
			PTR_registr<=PTR_registr-1;
		elsif (PTR_inc='1') then --zvyseni o 1
			PTR_registr<=PTR_registr+1;
		end if;	
	end if;
	end process;
	DATA_ADDR<=PTR_registr; --jde do RAM na DATA_ADDR
	
-----------------MUX

MUX: process (MUXinput,DATA_RDATA, IN_DATA) is 
	begin
	
			case MUXinput is
					when "01" =>
						MUXoutput<=DATA_RDATA-1; --akutalni bunka -1
					when "10"  =>
						MUXoutput<=DATA_RDATA+1;  --akutalni bunka +1
					when "00"  =>
						MUXoutput<=IN_DATA; --hodnota ze vstupu
					when others  => 
						MUXoutput<=(others=>'0');
			end case;
		
	end process;
	
	DATA_WDATA<=MUXoutput; --zapis do RAM
	OUT_DATA<=DATA_RDATA;
	
-----------------FSM
  FSM_test: process(EN,CLK,RESET) is
  begin
  if (RESET='1') then --pokud mame reset
	Astate<=sStart;
	elsif (CLK'event) and (CLK ='1') then -- nabezna hrana 
		if(EN='1') then
		Astate<=Nstate; 
		end if;
	end if;	
  end process;
  
  FSM: process(Astate,IN_VLD,OUT_BUSY,CODE_DATA,DATA_RDATA,PC_registr) is
  begin
			PC_inc<='0'; --nulovani FSM vystupu
			PC_dec<='0';
			PC_ld<='0';
			
			PTR_inc<='0';
			PTR_dec<='0';
			
			IN_REQ<='0';
			OUT_WE<='0';
			DATA_EN<='0';
			CODE_EN<='0';
			DATA_WE<='0';
		
			
			MUXinput<="11";
			
			case Astate is
				when sStart =>
					Nstate<=sFetch;
				when sFetch => --povoleni znaku
					CODE_EN <='1';
					Nstate<=sDecode;
				when sDecode =>
						case CODE_DATA is --kontrola jaky znak
							when X"3E" => -- >
								Nstate <= sPtr_inc;
							when X"3C" => -- <
								Nstate <= sPtr_dec;
							when X"2B" => -- +
								Nstate <= sVal_inc;
							when X"2D" => -- -
								Nstate <= sVal_dec;
							when X"5B" => -- [
								Nstate <=  sWhile_begin;
							when X"5D" => -- ]
								Nstate <=  sWhile_end;
							when X"2E" => -- .
								Nstate <= sPrint;
							when X"2C" => -- ,
								Nstate <= sRead;
							when X"00" => -- null
								Nstate <= sNULL;
							when others =>
								PC_inc<='1';
								Nstate<=sFetch; 
						end case;
				
				when sPtr_inc => --ptr incerement (posun v pameti)
						PTR_inc<='1';
						PC_inc<='1';
						Nstate<=sFetch;
				when sPtr_dec =>
						PTR_dec<='1';
						PC_inc<='1';
						Nstate<=sFetch;	
				
				when sVal_inc => --increment hodnota (ascii +1)	
					DATA_EN<='1'; --povoleni pameti
					DATA_WE<='0'; --pro cteni
					Nstate<=sVal_inc2;
			
				when 	sVal_inc2 =>
					MUXinput<="10"; --inc
					DATA_EN<='1'; --povoleni pameti
					DATA_WE<='1'; --pro zapis
					PC_inc<='1';
					Nstate<=sFetch;
				
				when sVal_dec => --decrement hodnota (ascii -1)	
					DATA_EN<='1'; --povoleni pameti
					DATA_WE<='0'; --pro cteni
					Nstate<=sVal_dec2;
				
				when 	sVal_dec2 =>
					MUXinput<="01"; --dec
					DATA_EN<='1'; --povoleni pameti
					DATA_WE<='1'; --pro zapis
					PC_inc<='1';
					
					Nstate<=sFetch;
				
				when sPrint => --print na lcd
					DATA_EN<='1'; 
					DATA_WE<='0'; 	
					Nstate<=sPrint2;
				when sPrint2 =>
						if (OUT_BUSY = '0') then --muzeme vypisovat
							OUT_WE<='1'; 
							PC_inc<='1';
							Nstate<=sFetch;
						else
							Nstate<=sPrint2;
						end if;

				when sRead=>
					IN_REQ<='1';
					Nstate<=sRead2;
				when sRead2=>
					if (IN_VLD='1') then --validni data
						MUXinput<="00";
						DATA_EN<='1'; --povoleni pameti
						DATA_WE<='1'; --pro zapis
						PC_inc<='1';
						Nstate<=sFetch;
					else
						Nstate<=sRead2;	
					end if;
					
			
	
			when sWhile_begin =>
					PC_inc<='1';
					RAS_registr<=PC_registr; --RAS[0] ‹ PC
					Nstate<=sWhile_begin2;
						
			when sWhile_begin2 =>		
					if (DATA_RDATA="00000000") then -- (ram[PTR] == 0
						CODE_EN<='1';
						Nstate<=sWhile_begin3;
					else
							Nstate<=sFetch;
					end if;	
			
			when sWhile_begin3 => --LOOP
				
					if (CODE_DATA=X"5D") then --ukonocovaci while zavorka
						Nstate<=sFetch; --jedeme dal
					else
					PC_inc<='1';
					DATA_EN<='1'; --povoleni pameti
					DATA_WE<='0'; --pro cteni
					
					Nstate<=sWhile_begin3;
					end if;
				
					
				when sWhile_end =>
					if (DATA_RDATA="00000000") then
						PC_inc<='1';
						Nstate<=sFetch;
					else
						PC_ld<='1';
						Nstate<=sFetch;
					end if;		
					


				when sNULL=> --zastaveni programu (return) 
				Nstate<=sNULL;
					end case;
					
				
			
  end process;
	
end behavioral;
 
