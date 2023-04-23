-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2020 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): DOPLNIT
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

 signal pc_reg  : std_logic_vector(11 downto 0);
 signal pc_inc  : std_logic;
 signal pc_dec  : std_logic;
 signal pc_ld   : std_logic;

 signal ras_reg  : std_logic_vector(11 downto 0);

 signal cnt_reg : std_logic_vector(11 downto 0);
 signal cnt_inc : std_logic;
 signal cnt_dec : std_logic;

 signal ptr_reg : std_logic_vector(9 downto 0);
 signal ptr_inc : std_logic;
 signal ptr_dec : std_logic;

 type fsm_state is(
 	s_start,
	s_fetch,
	s_decode,
	s_ptr_inc, -- >
	s_ptr_dec, -- <
	s_val_inc, -- +
	s_val_inc2,
	s_val_inc3,
	s_val_dec, -- -
	s_val_dec2,
	s_val_dec3,
	s_while_start, -- [
	s_while,
	s_while2,
	s_while_end, --]
	s_while_end2,
	s_putchar, -- .
	s_putchar2,
	s_getchar, -- ,
	s_getchar2,
	s_stop_prg, -- null
	s_others
 );

 signal state  : fsm_state := s_start;
 signal nstate : fsm_state;

 signal mx_DATA_WDATA : std_logic_vector(7 downto 0) := (others => '0');
 signal mx_sel : std_logic_vector(1 downto 0) := (others => '0');
 

begin
	pc: process (CLK, RESET, pc_inc, pc_dec, pc_ld) is
	begin
		if RESET = '1' then
			pc_reg <= (others => '0');
		elsif rising_edge(CLK) then 
			if pc_inc = '1' then
			       pc_reg <= pc_reg + 1;
			elsif pc_dec = '1' then
				pc_reg <= pc_reg - 1;
			elsif pc_ld = '1' then
				pc_reg <= ras_reg;
			end if;
		end if;
	end process;
	CODE_ADDR <= pc_reg;

	cnt: process (CLK, RESET, cnt_inc, cnt_dec) is
	begin
		if RESET = '1' then
			cnt_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if cnt_inc = '1' then
				cnt_reg <= cnt_reg + 1;
			elsif cnt_dec = '1' then
				cnt_reg <= cnt_reg - 1;
			end if;
		end if;
	end process;

	ptr: process (CLK, RESET, ptr_inc, ptr_dec) is
	begin
		if RESET = '1' then
			ptr_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if ptr_inc = '1' then
				ptr_reg <= ptr_reg + 1;
			elsif ptr_dec = '1' then
				ptr_reg <= ptr_reg - 1;
			end if;
		end if;
	end process;
	DATA_ADDR <= ptr_reg;

	OUT_DATA <= DATA_RDATA;

	multiplexor: process (CLK, RESET, mx_sel) is
	begin
		if RESET = '1' then
			mx_DATA_WDATA <= (others => '0');
		elsif rising_edge(CLK) then
			case mx_sel is
				when "00" =>
					mx_DATA_WDATA <= IN_DATA;

				when "01" =>
					mx_DATA_WDATA <= DATA_RDATA + 1;

				when "10" =>
					mx_DATA_WDATA <= DATA_RDATA - 1;

				when others =>
					mx_DATA_WDATA <= (others => '0');

			end case;
		end if;
	end process;
	DATA_WDATA <= mx_DATA_WDATA;

	fsm_present_state: process (CLK, RESET, EN) is
	begin
		if RESET = '1' then
			state <= s_start;
		elsif rising_edge(CLK) then
			if EN = '1' then
				state <= nstate;
			end if;
		end if;
	end process;
	
	fsm_next_state: process (OUT_BUSY, IN_VLD, CODE_DATA, cnt_reg, DATA_RDATA, state) is
	begin
		OUT_WE <= '0';
		IN_REQ <= '0';
		CODE_EN <= '0';
		pc_inc <= '0';
		pc_dec <= '0';
		pc_ld <= '0';
		cnt_inc <= '0';
		cnt_dec <= '0';
		ptr_inc <= '0';
		ptr_dec <= '0';
		mx_sel <= "00";
		DATA_WE <= '0';
		DATA_EN <= '0';
	       	
		case state is
			when s_start =>
				nstate <= s_fetch;
			when s_fetch =>
				CODE_EN <= '1';
				nstate <= s_decode;
			when s_decode =>
				case CODE_DATA is
					when x"3E" =>
						nstate <= s_ptr_inc;
					when x"3C" =>
						nstate <= s_ptr_dec;
					when x"2B" =>
						nstate <= s_val_inc;
					when x"2D" =>
						nstate <= s_val_dec;
					when x"5B" =>
						nstate <= s_while_start;
					when x"5D" =>
						nstate <= s_while_end;
					when x"2E" =>
						nstate <= s_putchar;
					when x"2C" =>
						nstate <= s_getchar;
					when x"00" =>
						nstate <= s_stop_prg;
					when others =>
						nstate <= s_others;
				end case;
			when s_ptr_inc =>
				ptr_inc <= '1';
				pc_inc <= '1';
				nstate <= s_fetch;
			when s_ptr_dec =>
				ptr_dec <= '1';
				pc_inc <= '1';
				nstate <= s_fetch;
			when s_val_inc =>
				pc_inc <= '1'; 
				DATA_EN <= '1';
				DATA_WE <= '0';
				nstate <= s_val_inc2;
			when s_val_inc2 =>
				mx_sel <= "01";
				nstate <= s_val_inc3;
			when s_val_inc3 =>
				DATA_EN <= '1';
				DATA_WE <= '1';
				nstate <= s_fetch;
			when s_val_dec =>
				pc_inc <= '1';
				DATA_EN <= '1';
				DATA_WE <= '0';
				nstate <= s_val_dec2;
			when s_val_dec2 =>
				mx_sel <= "10";
				nstate <= s_val_dec3;
			when s_val_dec3 =>
				DATA_EN <= '1';
				DATA_WE <= '1';
				nstate <= s_fetch;
			when s_while_start =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				pc_inc <= '1';
				nstate <= s_while;
			when s_while =>
				if DATA_RDATA /= (DATA_RDATA'range => '0') then
					ras_reg <= pc_reg;
					nstate <= s_fetch;
				else
					nstate <= s_while2;
				end if;
			when s_while2 =>
				if CODE_DATA /= X"5D" then
					pc_inc <= '1';
					CODE_EN <= '1';
					nstate <= s_while2;
				else
					nstate <= s_fetch;
				end if;
			when s_while_end =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				nstate <= s_while_end2;
			when s_while_end2 =>
				if DATA_RDATA /= (DATA_RDATA'range => '0') then
					pc_ld <= '1';
					nstate <= s_fetch;
				else
					pc_inc <= '1';
					nstate <= s_fetch;
				end if;
			when s_putchar =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				nstate <= s_putchar2;
			when s_putchar2 =>
				if OUT_BUSY = '1' then
					DATA_EN <= '1';
					DATA_WE <= '0';
					nstate <= s_putchar2;
				else
					pc_inc <= '1';
					OUT_WE <= '1';
					nstate <= s_fetch;
				end if;
			when s_getchar =>
				IN_REQ <= '1';
				mx_sel <= "00";
				nstate <= s_getchar2;
			when s_getchar2 =>
				if IN_VLD = '0' then
					IN_REQ <= '1';
					mx_sel <= "00";
					nstate <= s_getchar2;
				else
					DATA_EN <= '1';
					DATA_WE <= '1';
					pc_inc <= '1';
					nstate <= s_fetch;
				end if;
			when s_stop_prg =>
				nstate <= s_stop_prg;
			when s_others =>
				pc_inc <= '1';
			       	nstate <= s_fetch;
			when others =>
				null;	
		end case;
	end process;

end behavioral;
 
