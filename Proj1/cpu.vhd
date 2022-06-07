-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): xhanus19
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
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- PC block
	signal pc_reg : std_logic_vector(11 downto 0);
	signal pc_while_start : std_logic_vector(11 downto 0);
	signal pc_inc : std_logic;
	signal pc_dec : std_logic;

 -- PTR block
	signal ptr_reg : std_logic_vector(9 downto 0);
	signal ptr_inc : std_logic;
	signal ptr_dec : std_logic;

	type fsm_state is (
		fsm_sleep,
		fsm_read,
		fsm_decode,
		fsm_return,
		fsm_skip,
		
		fsm_pointer_inc, --D
		fsm_pointer_dec, --D
		
		fsm_value_inc_load, --D
		fsm_value_inc_write, --D
		
		fsm_value_dec_load, --D
		fsm_value_dec_write, --D
		
		fsm_while_start_load,
		fsm_while_start,
		fsm_while_skip,
		fsm_while_end_load,
		fsm_while_end,
		fsm_while_go_to_start,
		
		fsm_print_value_busy, --D
		fsm_print_value, -- '.' -D
		
		fsm_save_value, -- ','
		fsm_save_value_valid,
		
		fsm_while_break, --'~'
		
		fsm_null -- 'null' -D
	
	);
	signal fsm_current_state : fsm_state := fsm_sleep;
	signal fsm_next_state : fsm_state;

begin

	pc_cntr: process(RESET, CLK, pc_reg, pc_inc, pc_dec)
	begin
		if (RESET='1') then
			pc_reg <= (others=>'0');
		elsif rising_edge(CLK) then
			if (pc_inc='1') then
				pc_reg <= pc_reg + 1;
			elsif (pc_dec='1') then
				pc_reg <= pc_reg - 1;
			end if;
		end if;
	end process;

	CODE_ADDR <= pc_reg;
	
	ptr_cntr: process(RESET, CLK, ptr_reg, ptr_inc, ptr_dec)
	begin
		if (RESET='1') then
			ptr_reg <= (others=>'0');
		elsif rising_edge(CLK) then
			if (ptr_inc='1') then
				ptr_reg <= ptr_reg + 1;
			elsif (ptr_dec='1') then
				ptr_reg <= ptr_reg - 1;
			end if;
		end if;
	end process;	

	DATA_ADDR <= ptr_reg;

	--FSM actual state
	fsm_init: process(CLK, RESET, EN)
	begin
		if (RESET='1') then
			fsm_current_state <= fsm_sleep;
		elsif (CLK'event) and (CLK = '1') then
			if EN='1' then
				fsm_current_state <= fsm_next_state;
			end if;
		end if;
	
	end process;
	
	fsm: process(CLK, RESET, OUT_BUSY, IN_VLD, CODE_DATA, DATA_RDATA, fsm_current_state, pc_reg, IN_DATA, pc_while_start)
	begin
		pc_inc <= '0';
		pc_dec <= '0';
		
		ptr_inc <= '0';
		ptr_dec <= '0';
		
		DATA_EN <= '0';
		CODE_EN <= '0';
		IN_REQ <= '0';
		OUT_WREN <= '0';
		
		case fsm_current_state is
         when fsm_sleep =>            
				fsm_next_state <= fsm_read;
			
			when fsm_read =>       
				CODE_EN <= '1';
				fsm_next_state <= fsm_decode;
			
			when fsm_decode =>       
				case CODE_DATA is
					when X"3E" =>
						fsm_next_state <= fsm_pointer_inc;
					when X"3C" =>
						fsm_next_state <= fsm_pointer_dec;
					when X"2B" =>
						fsm_next_state <= fsm_value_inc_load;
					when X"2D" =>
						fsm_next_state <= fsm_value_dec_load;
					when X"2E" => -- .
						fsm_next_state <= fsm_print_value;
					when X"00" =>
						fsm_next_state <= fsm_null;
					when X"5B" => --loop start '['
						fsm_next_state <= fsm_while_start_load;
					when X"5D" => --loop end ']'
						fsm_next_state <= fsm_while_end_load;
					when X"7E" => -- ~
						fsm_next_state <= fsm_while_skip;
					when X"2C" => -- ,
						fsm_next_state <= fsm_save_value;
					when others=>
						pc_inc <= '1';
						fsm_next_state <= fsm_read;
				end case;

			when fsm_while_start_load =>
				DATA_WREN <= '0';
				DATA_EN <= '1';
				fsm_next_state <= fsm_while_start;
				
			when fsm_while_start =>
						if DATA_RDATA = 0 then
							CODE_EN <= '1';
							fsm_next_state <= fsm_while_skip;
						else
							pc_while_start <= pc_reg; -- get next value after '[' --DEBUG : [5]
							pc_inc <= '1';
							fsm_next_state <= fsm_read;
						end if;
			
			when fsm_while_skip =>
				if CODE_DATA = X"5D" then
					fsm_next_state <= fsm_read;
				else
					CODE_EN <= '1';
					pc_inc <= '1';
					fsm_next_state <= fsm_while_skip;
				end if;
			
			when fsm_while_end_load =>
				DATA_WREN <= '0';
				DATA_EN <= '1';
				fsm_next_state <= fsm_while_end;
			
			when fsm_while_end =>
						if DATA_RDATA = 0 then
							pc_inc <= '1';
							fsm_next_state <= fsm_read; -- chod dalej
						else
							fsm_next_state <= fsm_while_go_to_start;
						end if;
						
			when fsm_while_go_to_start =>
						if pc_while_start = pc_reg then
							fsm_next_state <= fsm_read;
						else
							pc_dec <= '1';
							fsm_next_state <= fsm_while_go_to_start;
						end if;
			
			when fsm_value_inc_load =>     
						--RDATA <- ADDR
				      DATA_EN<='1';
						DATA_WREN<='0';
						fsm_next_state <= fsm_value_inc_write;

			when fsm_value_inc_write =>       
				      DATA_EN <= '1';
						DATA_WREN <= '1';
						DATA_WDATA <= DATA_RDATA + '1';
						pc_inc <= '1';
						fsm_next_state <= fsm_read;
						
			when fsm_value_dec_load =>     
						--RDATA <- ADDR
				      DATA_EN<='1';
						DATA_WREN<='0';
						fsm_next_state <= fsm_value_dec_write;

			when fsm_value_dec_write =>       
				      DATA_EN <= '1';
						DATA_WREN <= '1';
						DATA_WDATA <= DATA_RDATA - '1';
						pc_inc <= '1';
						fsm_next_state <= fsm_read;
						
			when fsm_save_value =>
				IN_REQ <= '1';
				fsm_next_state <= fsm_save_value_valid;		

			when fsm_save_value_valid =>
				if IN_VLD = '1' then
					DATA_WREN <= '1';
					DATA_EN <= '1';
					DATA_WDATA <= IN_DATA;
					pc_inc <= '1';
					fsm_next_state <= fsm_read;
				else
					IN_REQ <= '1';
					fsm_next_state <= fsm_save_value_valid;
				end if;
						
			when fsm_print_value =>   
				DATA_EN<='1';
				DATA_WREN<='0';
				fsm_next_state <= fsm_print_value_busy;
						
			when fsm_print_value_busy =>
				if OUT_BUSY = '1' then
					fsm_next_state <= fsm_print_value_busy;
				else
					OUT_WREN <= '1';
					OUT_DATA <= DATA_RDATA;
					fsm_next_state <= fsm_read;
					pc_inc <= '1';
				end if;
			
			when fsm_pointer_inc =>  
				ptr_inc <= '1';
				pc_inc <= '1';
				fsm_next_state <= fsm_read;
			
			when fsm_pointer_dec =>  
				ptr_dec <= '1';
				pc_inc <= '1';
				fsm_next_state <= fsm_read;
			
			when fsm_null =>
				fsm_next_state <= fsm_return;
						
         when others =>
            null;
      end case;
		
	end process;
	
end behavioral;
 
