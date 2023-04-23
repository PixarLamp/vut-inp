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
	signal shift: std_logic_vector(7 downto 0);
       	signal plus_correction: std_logic_vector(7 downto 0); 
	signal minus_correction: std_logic_vector(7 downto 0);
	type tState is (add, subtract);
	signal state: tState := add;
	signal nextState: tState := subtract;
	signal fsmMealy: std_logic_vector(1 downto 0);
	signal hash: std_logic_vector(7 downto 0) := "00100011";
begin
	ShiftSize: process (DATA, KEY) is
	begin
		shift <= KEY - 64;
	end process;

	plusCorrProcess: process (shift, DATA) is
		variable x: std_logic_vector(7 downto 0);
	begin
	      	x := DATA;
		x := x + shift;
		if (x > 90) then
			x := x - 26;
		end if;
		plus_correction <= x;	
	end process;

	minusCorrProcess: process (shift, DATA) is
		variable x: std_logic_vector(7 downto 0);
	begin
		x := DATA;
		x := x - shift;
		if (x < 65) then
			x := x + 26;
		end if;
		minus_correction <= x;
	end process;
	
	stateLogic: process (CLK, RST) is
	begin
		if RST = '1' then
			state <= add;
		elsif rising_edge(CLK) then
			state <= nextState;
		end if;
	end process;
	
	fsm_mealy: process (state, DATA, RST) is
	begin
		nextState <= state;
		if state = subtract then
			fsmMealy <= "10";
			nextState <= add;
		elsif state = add then
			nextState <= subtract;
			fsmMealy <= "01";
		end if;

		if (DATA < 58 and DATA > 47) then
			fsmMealy <= "00";
		end if;
		if RST = '1'
		then
			fsmMealy <= "00";
		end if;
	end process;
	
	multiplexor: process(fsmMealy, plus_correction, minus_correction) is
	begin
		if fsmMealy = "10" then
			CODE <= minus_correction;
		elsif fsmMealy = "01" then
			CODE <= plus_correction;
		else
			CODE <= hash;
		end if;
	end process;

end behavioral;
