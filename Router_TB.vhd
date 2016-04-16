
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Router_Package.all;
entity router_tb is
	 
end router_tb; 

architecture behavior of router_tb is

component router is
  generic (
        DATA_WIDTH: integer := 32;
        current_address : integer := 0;
        Rxy_rst : integer := 60;
        Cx_rst : integer := 10
    );
    port (
    reset, clk: in std_logic;
    DCTS_N, DCTS_E, DCTS_w, DCTS_S, DCTS_L: in std_logic;
    DRTS_N, DRTS_E, DRTS_W, DRTS_S, DRTS_L: in std_logic;
    In_N, In_E, In_W, In_S, In_L : in std_logic_vector (DATA_WIDTH-1 downto 0);
    RTS_N, RTS_E, RTS_W, RTS_S, RTS_L: out std_logic;
    CTS_N, CTS_E, CTS_w, CTS_S, CTS_L: out std_logic;
    Out_N, Out_E, Out_W, Out_S, Out_L: out std_logic_vector (DATA_WIDTH-1 downto 0));
end component; 
 
 signal reset,clk: std_logic :='0';
 signal DCTS_N, DCTS_E, DCTS_w, DCTS_S, DCTS_L: std_logic := '0';
 signal DRTS_N, DRTS_E, DRTS_W, DRTS_S, DRTS_L: std_logic := '0';
 signal RTS_N, RTS_E, RTS_W, RTS_S, RTS_L: std_logic;
 signal CTS_N, CTS_E, CTS_w, CTS_S, CTS_L: std_logic;
 signal In_N, In_E, In_W, In_S, In_L: std_logic_vector(31 downto 0)  := (others=>'0');
 signal Out_N, Out_E, Out_W, Out_S, Out_L: std_logic_vector(31 downto 0);
 constant clk_period : time := 1 ns;
 

begin
-- all the FIFOs
 UUT: router generic map (DATA_WIDTH  => 32, current_address=> 0, Rxy_rst => 60, Cx_rst => 10)
   PORT MAP (reset, clk, 
    DCTS_N, DCTS_E, DCTS_w, DCTS_S, DCTS_L,
    DRTS_N, DRTS_E, DRTS_W, DRTS_S, DRTS_L,
    In_N, In_E, In_W, In_S, In_L,
    RTS_N, RTS_E, RTS_W, RTS_S, RTS_L,
    CTS_N, CTS_E, CTS_w, CTS_S, CTS_L,
    Out_N, Out_E, Out_W, Out_S, Out_L);  

   clk_process :process
   begin
        clk <= '0';
        wait for clk_period/2;   
        clk <= '1';
        wait for clk_period/2; 
   end process;

  reset <= '1' after 10 ns;

  process (clk)
   begin
      if clk'event and clk = '1' then
        if reset = '1' then
          DRTS_E <= '1';
          In_E <= Header_gen(1, 1, 0, 1);
          DCTS_L <= '1';
          if CTS_E ='1'then
            In_E <= Body_gen(1, 100);
          end if; 
      end if;
    end if;
   end process;
end;