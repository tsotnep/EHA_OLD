
import random 

import sys
if '-D'  in sys.argv[1:]:
  network_dime = int(sys.argv[sys.argv.index('-D')+1])
  print network_dime
else:
  network_dime = 4

data_width = 32
noc_file = open('tb_network_'+str(network_dime)+"x"+str(network_dime)+'.vhd', 'w')


noc_file.write("--Copyright (C) 2016 Siavoosh Payandeh Azad\n")
noc_file.write("------------------------------------------------------------\n")
noc_file.write("-- This file is automatically generated!\n")
noc_file.write("-- Here are the parameters:\n")
noc_file.write("-- \t network size x:"+str(network_dime)+"\n")
noc_file.write("-- \t network size y:"+str(network_dime)+"\n")
noc_file.write("------------------------------------------------------------\n\n")

noc_file.write("library ieee;\n")
noc_file.write("use ieee.std_logic_1164.all;\n")
noc_file.write("use IEEE.STD_LOGIC_ARITH.ALL;\n")
noc_file.write("use IEEE.STD_LOGIC_UNSIGNED.ALL;\n")
noc_file.write("use work.TB_Package.all;\n\n")

noc_file.write("entity tb_network_"+str(network_dime)+"x"+str(network_dime)+" is\n")
 
noc_file.write("end tb_network_"+str(network_dime)+"x"+str(network_dime)+"; \n")


noc_file.write("\n\n")
noc_file.write("architecture behavior of tb_network_"+str(network_dime)+"x"+str(network_dime)+" is\n\n")

noc_file.write("-- Declaring network component\n")

 
noc_file.write("component network_"+str(network_dime)+"x"+str(network_dime)+" is\n")
noc_file.write(" generic (DATA_WIDTH: integer := 32);\n")
noc_file.write("port (reset: in  std_logic; \n")
noc_file.write("\tclk: in  std_logic; \n")
for i in range(network_dime*network_dime):
  noc_file.write("\t--------------\n")
  noc_file.write("\tRX_L_"+str(i)+": in std_logic_vector (DATA_WIDTH-1 downto 0);\n")
  noc_file.write("\tRTS_L_"+str(i)+", CTS_L_"+str(i)+": out std_logic;\n")
  noc_file.write("\tDRTS_L_"+str(i)+", DCTS_L_"+str(i)+": in std_logic;\n")
  if i == network_dime*network_dime-1:
    noc_file.write("\tTX_L_"+str(i)+": out std_logic_vector (DATA_WIDTH-1 downto 0)\n")
  else:
    noc_file.write("\tTX_L_"+str(i)+": out std_logic_vector (DATA_WIDTH-1 downto 0);\n")
noc_file.write("            ); \n")
noc_file.write("end component; \n")

noc_file.write("\n")
noc_file.write("-- generating bulk signals...\n")
for i in range(0, network_dime*network_dime):
    noc_file.write("\tsignal RX_L_"+str(i)+", TX_L_"+str(i)+":  std_logic_vector ("+str(data_width-1)+" downto 0);\n")
    noc_file.write("\tsignal RTS_L_"+str(i)+", DRTS_L_"+str(i)+", CTS_L_"+str(i)+", DCTS_L_"+str(i) + ": std_logic;\n")
    noc_file.write("\t--------------\n")
noc_file.write(" constant clk_period : time := 1 ns;\n")
noc_file.write("signal reset,clk: std_logic :='0';\n")

noc_file.write("\n")
noc_file.write("begin\n\n")


noc_file.write("   clk_process :process\n")
noc_file.write("   begin\n")
noc_file.write("        clk <= '0';\n")
noc_file.write("        wait for clk_period/2;   \n")
noc_file.write("        clk <= '1';\n")
noc_file.write("        wait for clk_period/2; \n")
noc_file.write("   end process;\n")
noc_file.write("\n")
noc_file.write("reset <= '1' after 1 ns;\n")

noc_file.write("-- instantiating the network\n")

noc_file.write("NoC: network_"+str(network_dime)+"x"+str(network_dime)+" generic map (DATA_WIDTH  => "+str(data_width)+")\n")
noc_file.write("PORT MAP (reset, clk, \n")
for i in range(network_dime*network_dime):    
  noc_file.write("\tRX_L_"+str(i)+", RTS_L_"+str(i)+", CTS_L_"+str(i)+", DRTS_L_"+str(i)+", DCTS_L_"+str(i)+", ")
  if i == network_dime*network_dime-1:
    noc_file.write("TX_L_"+str(i)+");\n")
  else:
    noc_file.write("TX_L_"+str(i)+",\n")

noc_file.write("\n")
noc_file.write("-- connecting the packet generators\n")
for i in range(0, network_dime*network_dime):  
  random_node = random.randint(0, network_dime*network_dime-1)
  while i == random_node:
    random_node = random.randint(0, (network_dime*network_dime)-1)
  random_length  = random.randint(3, 10)
  random_start = random.randint(3, 50)
  random_end = random.randint(random_start, 200)

  noc_file.write("gen_packet("+str(random_length)+", "+str(i)+", "+str(random_node)+", 1, "+str(random_start)+", "+str(random_end)+" ns, clk, CTS_L_"+str(i)+", DRTS_L_"+str(i)+", RX_L_"+str(i)+");\n")

noc_file.write("\n")
noc_file.write("-- connecting the packet receivers\n")
for i in range(0, network_dime*network_dime):    
  noc_file.write("get_packet("+str(data_width)+", 5,  clk, DCTS_L_"+str(i)+", RTS_L_"+str(i)+", TX_L_"+str(i)+");\n")

noc_file.write("end;\n")
