library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- rozhrani Vigenerovy sifry
entity vigenere is
   port(
         CLK : in std_logic;
         RST : in std_logic;
         DATA : in std_logic_vector(7 downto 0);
         KEY : in std_logic_vector(7 downto 0);

         CODE : out std_logic_vector(7 downto 0)
    );
end vigenere;

-- V souboru fpga/sim/tb.vhd naleznete testbench, do ktereho si doplnte
-- znaky vaseho loginu (velkymi pismeny) a znaky klice dle vaseho prijmeni.

architecture behavioral of vigenere is

    -- Sem doplnte definice vnitrnich signalu, prip. typu, pro vase reseni,
    -- jejich nazvy doplnte tez pod nadpis Vigenere Inner Signals v souboru
    -- fpga/sim/isim.tcl. Nezasahujte do souboru, ktere nejsou explicitne
    -- v zadani urceny k modifikaci.
	signal VelikostPosunu: std_logic_vector(7 downto 0);
	signal KladnaKorekce: std_logic_vector(7 downto 0);
	signal ZapornaKorekce: std_logic_vector(7 downto 0);
	type FSMstate is (add, sub);
	signal pstate: FSMstate;
	signal nstate: FSMstate;
	signal mealyout: std_logic_vector(1 downto 0); --2 bity (00 pricitani, 11 odecitani, 10 reset, 01 number)
	
	
begin

    -- Sem doplnte popis obvodu. Doporuceni: pouzivejte zakladni obvodove prvky
    -- (multiplexory, registry, dekodery,...), jejich funkce popisujte pomoci
    -- procesu VHDL a propojeni techto prvku, tj. komunikaci mezi procesy,
    -- realizujte pomoci vnitrnich signalu deklarovanych vyse.

    -- DODRZUJTE ZASADY PSANI SYNTETIZOVATELNEHO VHDL KODU OBVODOVYCH PRVKU,
    -- JEZ JSOU PROBIRANY ZEJMENA NA UVODNICH CVICENI INP A SHRNUTY NA WEBU:
    -- http://merlin.fit.vutbr.cz/FITkit/docs/navody/synth_templates.html.
	 
	
	vypocetvelikosti: process (DATA, KEY) is --Pomoci data a key vypocet posunu podle znaku zacatku loginu (S,I)
														--KEY-64(A=65 in ASCII) if KEY=A 65-64=1 posun o jeden znak
	begin	
		VelikostPosunu <= (KEY - 64); 
	end process;

	posunzacatek: process (VelikostPosunu, DATA) is --posun pres konec abecedy na zacatek
			variable pom: std_logic_vector(7 downto 0);
	begin	
		pom:=DATA;
		pom:=pom+VelikostPosunu; --ke znaku pricteme posun
		if (pom>90) then  --if DATA=Z, VelikostPosunu=1, pom=91 91-26=	(A)
		pom:=pom-26;
		end if;

		KladnaKorekce<=pom;

 	end process;

	posunkonec: process (VelikostPosunu, DATA) is  --posun pres zacatek abecedy na konec
		variable pom: std_logic_vector(7 downto 0);
	begin	
		pom:=DATA;
		pom:=pom-VelikostPosunu;
		if (pom<65) then --if DATA=(A), pom=1, 65-1=64 65+26=90 (Z)
		pom:=pom+26;
		end if;

		ZapornaKorekce<=pom;
		
 	end process;
	
	pstateprocess: process (RST, CLK) is
	begin
		if (RST='1') then --defaultni nastaveni statu pri resetu
		pstate<=add;
		elsif (CLK'event) and (CLK='1') then
		pstate<=nstate;
		end if;
	end process;
	
	mealy: process(pstate, DATA,RST) is	
	begin
		nstate<=add;
		
		--vystup mealyout (vystup FSMmealy) ridicim vstupem MUX
	if (RST='1') then
		mealyout<="10"; --rest (pouze na zacatku)
		elsif(DATA>47) and (DATA<58) then  --if is a number
			mealyout<="01"; --hastag
			elsif(pstate=add) then
				nstate<=sub;
				mealyout<="00"; --pricitani v abecede
				elsif (pstate=sub) then
					nstate<=add;
					mealyout<="11"; --odecitani v abecede			
		end if;

						
		end process;

		--MUX (INPUT KladnaKorekce, ZapornaKorekce, SEL mealyout, OUTPUT CODE)

		CODE <= KladnaKorekce when (mealyout="00") else --pouzit pricitani
			ZapornaKorekce when (mealyout="11") else --pouzit odecitani
			"00100011"; --jinak # (number or reset)
				


end behavioral;


