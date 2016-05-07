--Copyright (C) 2016 Siavoosh Payandeh Azad

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity router is
    generic(
        DATA_WIDTH      : integer := 32;
        current_address : integer := 0;
        Rxy_rst         : integer := 60;
        Cx_rst          : integer := 10;
        NoC_size        : integer := 4
    );
    port(
        reset, clk                             : in  std_logic;
        DCTS_N, DCTS_E, DCTS_w, DCTS_S, DCTS_L : in  std_logic;
        DRTS_N, DRTS_E, DRTS_W, DRTS_S, DRTS_L : in  std_logic;
        RX_N, RX_E, RX_W, RX_S, RX_L           : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        RTS_N, RTS_E, RTS_W, RTS_S, RTS_L      : out std_logic;
        CTS_N, CTS_E, CTS_w, CTS_S, CTS_L      : out std_logic;
        TX_N, TX_E, TX_W, TX_S, TX_L           : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end router;

architecture behavior of router is
    COMPONENT FIFO
        generic(
            DATA_WIDTH : integer := 32
        );
        port(reset     : in  std_logic;
             clk       : in  std_logic;
             RX        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
             DRTS      : in  std_logic;
             read_en_N : in  std_logic;
             read_en_E : in  std_logic;
             read_en_W : in  std_logic;
             read_en_S : in  std_logic;
             read_en_L : in  std_logic;
             CTS       : out std_logic;
             empty_out : out std_logic;
             Data_out  : out std_logic_vector(DATA_WIDTH - 1 downto 0)
        );
    end COMPONENT;

    COMPONENT Arbiter
        port(reset                                       : in  std_logic;
             clk                                         : in  std_logic;
             Req_N, Req_E, Req_W, Req_S, Req_L           : in  std_logic;
             DCTS                                        : in  std_logic;
             Grant_N, Grant_E, Grant_W, Grant_S, Grant_L : out std_logic;
             Xbar_sel                                    : out std_logic_vector(4 downto 0);
             RTS                                         : out std_logic
        );
    end COMPONENT;

    COMPONENT LBDR is
        generic(
            cur_addr_rst : integer := 0;
            Rxy_rst      : integer := 60;
            Cx_rst       : integer := 8;
            NoC_size     : integer := 4
        );
        port(reset                             : in  std_logic;
             clk                               : in  std_logic;
             empty                             : in  std_logic;
             flit_type                         : in  std_logic_vector(2 downto 0);
             dst_addr                          : in  std_logic_vector(3 downto 0);
             Req_N, Req_E, Req_W, Req_S, Req_L : out std_logic
        );
    end COMPONENT;

    COMPONENT XBAR is
        generic(
            DATA_WIDTH : integer := 32
        );
        port(
            North_in : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
            East_in  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
            West_in  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
            South_in : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
            Local_in : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
            sel      : in  std_logic_vector(4 downto 0);
            Data_out : out std_logic_vector(DATA_WIDTH - 1 downto 0)
        );
    end COMPONENT;

    -- ARBITER
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    -- Grant_XY : Grant signal generated from Arbiter for output X connected to FIFO of input Y
    signal Grant_NN_r, Grant_NE_r, Grant_NW_r, Grant_NS_r, Grant_NL_r : std_logic;
    signal Grant_EN_r, Grant_EE_r, Grant_EW_r, Grant_ES_r, Grant_EL_r : std_logic;
    signal Grant_WN_r, Grant_WE_r, Grant_WW_r, Grant_WS_r, Grant_WL_r : std_logic;
    signal Grant_SN_r, Grant_SE_r, Grant_SW_r, Grant_SS_r, Grant_SL_r : std_logic;
    signal Grant_LN_r, Grant_LE_r, Grant_LW_r, Grant_LS_r, Grant_LL_r : std_logic;
    signal Grant_NN, Grant_NE, Grant_NW, Grant_NS, Grant_NL                                              : std_logic;
    signal Grant_EN, Grant_EE, Grant_EW, Grant_ES, Grant_EL                                              : std_logic;
    signal Grant_WN, Grant_WE, Grant_WW, Grant_WS, Grant_WL                                              : std_logic;
    signal Grant_SN, Grant_SE, Grant_SW, Grant_SS, Grant_SL                                              : std_logic;
    signal Grant_LN, Grant_LE, Grant_LW, Grant_LS, Grant_LL                                              : std_logic;
    signal RTS_N_r, RTS_E_r, RTS_W_r, RTS_S_r, RTS_L_r                : std_logic;

    --redundant Arbiter
    signal Req_AREDNX_rd     : std_logic;
    signal Req_AREDEX_rd     : std_logic;
    signal Req_AREDWX_rd     : std_logic;
    signal Req_AREDSX_rd     : std_logic;
    signal Req_AREDLX_rd     : std_logic;
    signal DCTS_REDX_rd      : std_logic;
    signal Grant_AREDXN_rd   : std_logic;
    signal Grant_AREDXE_rd   : std_logic;
    signal Grant_AREDXW_rd   : std_logic;
    signal Grant_AREDXS_rd   : std_logic;
    signal Grant_AREDXL_rd   : std_logic;
    signal Xbar_sel_AREDX_rd : std_logic_vector(4 downto 0);
    signal RTS_REDX_rd       : std_logic;

    --Fault Information for redundant Arbiter
    signal Arbiter_Fault_Info : std_logic_vector(4 downto 0) := "00000";
    alias Fault_On_Arbiter_N  : std_logic IS Arbiter_Fault_Info(0);
    alias Fault_On_Arbiter_E  : std_logic IS Arbiter_Fault_Info(1);
    alias Fault_On_Arbiter_W  : std_logic IS Arbiter_Fault_Info(2);
    alias Fault_On_Arbiter_S  : std_logic IS Arbiter_Fault_Info(3);
    alias Fault_On_Arbiter_L  : std_logic IS Arbiter_Fault_Info(4);

    -- LBDR
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    signal Req_NN_r, Req_EN_r, Req_WN_r, Req_SN_r, Req_LN_r : std_logic;
    signal Req_NE_r, Req_EE_r, Req_WE_r, Req_SE_r, Req_LE_r : std_logic;
    signal Req_NW_r, Req_EW_r, Req_WW_r, Req_SW_r, Req_LW_r : std_logic;
    signal Req_NS_r, Req_ES_r, Req_WS_r, Req_SS_r, Req_LS_r : std_logic;
    signal Req_NL_r, Req_EL_r, Req_WL_r, Req_SL_r, Req_LL_r : std_logic;
    signal Req_NN, Req_EN, Req_WN, Req_SN, Req_LN                                              : std_logic;
    signal Req_NE, Req_EE, Req_WE, Req_SE, Req_LE                                              : std_logic;
    signal Req_NW, Req_EW, Req_WW, Req_SW, Req_LW                                              : std_logic;
    signal Req_NS, Req_ES, Req_WS, Req_SS, Req_LS                                              : std_logic;
    signal Req_NL, Req_EL, Req_WL, Req_SL, Req_LL                                              : std_logic;

    --redundant LBDR
    signal Req_XN_rd : std_logic;
    signal Req_XE_rd : std_logic;
    signal Req_XW_rd : std_logic;
    signal Req_XS_rd : std_logic;
    signal Req_XL_rd : std_logic;

    --Fault Information for redundant LBDR
    signal LBDR_Fault_Info : std_logic_vector(4 downto 0) := "00000";
    alias Fault_On_LBDR_N  : std_logic IS LBDR_Fault_Info(0);
    alias Fault_On_LBDR_E  : std_logic IS LBDR_Fault_Info(1);
    alias Fault_On_LBDR_W  : std_logic IS LBDR_Fault_Info(2);
    alias Fault_On_LBDR_S  : std_logic IS LBDR_Fault_Info(3);
    alias Fault_On_LBDR_L  : std_logic IS LBDR_Fault_Info(4);

    -- XBAR
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    signal TX_N_r, TX_E_r, TX_W_r, TX_S_r, TX_L_r                               : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal Xbar_sel_N_r, Xbar_sel_E_r, Xbar_sel_W_r, Xbar_sel_S_r, Xbar_sel_L_r : std_logic_vector(4 downto 0);
    signal Xbar_sel_N, Xbar_sel_E, Xbar_sel_W, Xbar_sel_S, Xbar_sel_L                                              : std_logic_vector(4 downto 0);

    --redundant XBAR
    signal Xbar_sel_XBRED_X_rd : std_logic_vector(4 downto 0);
    signal TX_REDX_rd          : std_logic_vector(DATA_WIDTH - 1 downto 0);

    --Fault Information for redundant XBAR
    signal Xbar_Fault_Info : std_logic_vector(4 downto 0) := "00000";
    alias Fault_On_Xbar_N  : std_logic IS Xbar_Fault_Info(0);
    alias Fault_On_Xbar_E  : std_logic IS Xbar_Fault_Info(1);
    alias Fault_On_Xbar_W  : std_logic IS Xbar_Fault_Info(2);
    alias Fault_On_Xbar_S  : std_logic IS Xbar_Fault_Info(3);
    alias Fault_On_Xbar_L  : std_logic IS Xbar_Fault_Info(4);

    -- FIFO
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    signal CTS_N_r, CTS_E_r, CTS_w_r, CTS_S_r, CTS_L_r                                    : std_logic;
    signal FIFO_D_out_N, FIFO_D_out_E, FIFO_D_out_W, FIFO_D_out_S, FIFO_D_out_L                                              : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal FIFO_D_out_N_r, FIFO_D_out_E_r, FIFO_D_out_W_r, FIFO_D_out_S_r, FIFO_D_out_L_r : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal empty_N, empty_E, empty_W, empty_S, empty_L                                                                       : std_logic;
    signal empty_N_r, empty_E_r, empty_W_r, empty_S_r, empty_L_r                          : std_logic;
    --redundant FIFO
    signal RX_X_rd                                                                                                    : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal DRTS_X_rd                                                                                                  : std_logic;
    signal Grant_NX_rd                                                                                                : std_logic;
    signal Grant_EX_rd                                                                                                : std_logic;
    signal Grant_WX_rd                                                                                                : std_logic;
    signal Grant_SX_rd                                                                                                : std_logic;
    signal Grant_LX_rd                                                                                                : std_logic;
    signal CTS_X_rd                                                                                                   : std_logic;
    signal empty_X_rd                                                                                                 : std_logic;
    signal FIFO_D_out_X_rd                                                                                            : std_logic_vector(DATA_WIDTH - 1 downto 0);

    --Fault Information for redundant FIFO
    signal FIFO_Fault_Info : std_logic_vector(4 downto 0) := "00000";
    alias Fault_On_FIFO_N  : std_logic IS FIFO_Fault_Info(0);
    alias Fault_On_FIFO_E  : std_logic IS FIFO_Fault_Info(1);
    alias Fault_On_FIFO_W  : std_logic IS FIFO_Fault_Info(2);
    alias Fault_On_FIFO_S  : std_logic IS FIFO_Fault_Info(3);
    alias Fault_On_FIFO_L  : std_logic IS FIFO_Fault_Info(4);

begin

    ------------------------------------------------------------------------------------------------------------------------------
    --                                      block diagram of one channel
    --
    --                                     .____________grant_________
    --                                     |                          ▲
    --                                     |     _______            __|_______
    --                                     |    |       |          |          |
    --                                     |    | LBDR  |---req--->|  Arbiter | <--handshake-->
    --                                     |    |_______|          |__________|     signals
    --                                     |       ▲                  |
    --                                   __▼___    | flit          ___▼__
    --                         RX ----->|      |   | type         |      |
    --                     <-handshake->| FIFO |---o------------->|      |-----> TX
    --                        signals   |______|           ------>|      |
    --                                                     ------>| XBAR |
    --                                                     ------>|      |
    --                                                     ------>|      |
    --                                                            |______|
    --
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------

    -- all the FIFOs
    FIFO_N : FIFO generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 RX        => RX_N,
                 DRTS      => DRTS_N,
                 read_en_N => '0',
                 read_en_E => Grant_EN,
                 read_en_W => Grant_WN,
                 read_en_S => Grant_SN,
                 read_en_L => Grant_LN,
                 CTS       => CTS_N_r,
                 empty_out => empty_N_r,
                 Data_out  => FIFO_D_out_N_r);

    FIFO_E : FIFO generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 RX        => RX_E,
                 DRTS      => DRTS_E,
                 read_en_N => Grant_NE,
                 read_en_E => '0',
                 read_en_W => Grant_WE,
                 read_en_S => Grant_SE,
                 read_en_L => Grant_LE,
                 CTS       => CTS_E_r,
                 empty_out => empty_E_r,
                 Data_out  => FIFO_D_out_E_r);

    FIFO_W : FIFO generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 RX        => RX_W,
                 DRTS      => DRTS_W,
                 read_en_N => Grant_NW,
                 read_en_E => Grant_EW,
                 read_en_W => '0',
                 read_en_S => Grant_SW,
                 read_en_L => Grant_LW,
                 CTS       => CTS_W_r,
                 empty_out => empty_W_r,
                 Data_out  => FIFO_D_out_W_r);

    FIFO_S : FIFO generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 RX        => RX_S,
                 DRTS      => DRTS_S,
                 read_en_N => Grant_NS,
                 read_en_E => Grant_ES,
                 read_en_W => Grant_WS,
                 read_en_S => '0',
                 read_en_L => Grant_LS,
                 CTS       => CTS_S_r,
                 empty_out => empty_S_r,
                 Data_out  => FIFO_D_out_S_r);

    FIFO_L : FIFO generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 RX        => RX_L,
                 DRTS      => DRTS_L,
                 read_en_N => Grant_NL,
                 read_en_E => Grant_EL,
                 read_en_W => Grant_WL,
                 read_en_S => Grant_SL,
                 read_en_L => '0',
                 CTS       => CTS_L_r,
                 empty_out => empty_L_r,
                 Data_out  => FIFO_D_out_L_r);

    FIFO_RED : FIFO generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 RX        => RX_X_rd,
                 DRTS      => DRTS_X_rd,
                 read_en_N => Grant_NX_rd,
                 read_en_E => Grant_EX_rd,
                 read_en_W => Grant_WX_rd,
                 read_en_S => Grant_SX_rd,
                 read_en_L => Grant_LX_rd,
                 CTS       => CTS_X_rd,
                 empty_out => empty_X_rd,
                 Data_out  => FIFO_D_out_X_rd);
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------

    -- all the LBDRs
    LBDR_N : LBDR generic map(cur_addr_rst => current_address,
                              Rxy_rst      => Rxy_rst,
                              Cx_rst       => Cx_rst,
                              NoC_size     => NoC_size)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 empty     => empty_N,
                 flit_type => FIFO_D_out_N(DATA_WIDTH - 1 downto DATA_WIDTH - 3),
                 dst_addr  => FIFO_D_out_N(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19),
                 Req_N     => Req_NN_r,
                 Req_E     => Req_NE_r,
                 Req_W     => Req_NW_r,
                 Req_S     => Req_NS_r,
                 Req_L     => Req_NL_r);

    LBDR_E : LBDR generic map(cur_addr_rst => current_address,
                              Rxy_rst      => Rxy_rst,
                              Cx_rst       => Cx_rst,
                              NoC_size     => NoC_size)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 empty     => empty_E,
                 flit_type => FIFO_D_out_E(DATA_WIDTH - 1 downto DATA_WIDTH - 3),
                 dst_addr  => FIFO_D_out_E(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19),
                 Req_N     => Req_EN_r,
                 Req_E     => Req_EE_r,
                 Req_W     => Req_EW_r,
                 Req_S     => Req_ES_r,
                 Req_L     => Req_EL_r);

    LBDR_W : LBDR generic map(cur_addr_rst => current_address,
                              Rxy_rst      => Rxy_rst,
                              Cx_rst       => Cx_rst,
                              NoC_size     => NoC_size)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 empty     => empty_W,
                 flit_type => FIFO_D_out_W(DATA_WIDTH - 1 downto DATA_WIDTH - 3),
                 dst_addr  => FIFO_D_out_W(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19),
                 Req_N     => Req_WN_r,
                 Req_E     => Req_WE_r,
                 Req_W     => Req_WW_r,
                 Req_S     => Req_WS_r,
                 Req_L     => Req_WL_r);

    LBDR_S : LBDR generic map(cur_addr_rst => current_address,
                              Rxy_rst      => Rxy_rst,
                              Cx_rst       => Cx_rst,
                              NoC_size     => NoC_size)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 empty     => empty_S,
                 flit_type => FIFO_D_out_S(DATA_WIDTH - 1 downto DATA_WIDTH - 3),
                 dst_addr  => FIFO_D_out_S(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19),
                 Req_N     => Req_SN_r,
                 Req_E     => Req_SE_r,
                 Req_W     => Req_SW_r,
                 Req_S     => Req_SS_r,
                 Req_L     => Req_SL_r);

    LBDR_L : LBDR generic map(cur_addr_rst => current_address,
                              Rxy_rst      => Rxy_rst,
                              Cx_rst       => Cx_rst,
                              NoC_size     => NoC_size)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 empty     => empty_L,
                 flit_type => FIFO_D_out_L(DATA_WIDTH - 1 downto DATA_WIDTH - 3),
                 dst_addr  => FIFO_D_out_L(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19),
                 Req_N     => Req_LN_r,
                 Req_E     => Req_LE_r,
                 Req_W     => Req_LW_r,
                 Req_S     => Req_LS_r,
                 Req_L     => Req_LL_r);

    LBDR_RED : LBDR generic map(cur_addr_rst => current_address,
                                Rxy_rst      => Rxy_rst,
                                Cx_rst       => Cx_rst,
                                NoC_size     => NoC_size)
        PORT MAP(reset     => reset,
                 clk       => clk,
                 empty     => empty_X_rd,
                 flit_type => FIFO_D_out_X_rd(DATA_WIDTH - 1 downto DATA_WIDTH - 3),
                 dst_addr  => FIFO_D_out_X_rd(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19),
                 Req_N     => Req_XN_rd,
                 Req_E     => Req_XE_rd,
                 Req_W     => Req_XW_rd,
                 Req_S     => Req_XS_rd,
                 Req_L     => Req_XL_rd);

    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------

    -- all the Arbiters
    Arbiter_N : Arbiter
        PORT MAP(reset    => reset,
                 clk      => clk,
                 Req_N    => '0',
                 Req_E    => Req_EN,
                 Req_W    => Req_WN,
                 Req_S    => Req_SN,
                 Req_L    => Req_LN,
                 DCTS     => DCTS_N,
                 Grant_N  => Grant_NN_r,
                 Grant_E  => Grant_NE_r,
                 Grant_W  => Grant_NW_r,
                 Grant_S  => Grant_NS_r,
                 Grant_L  => Grant_NL_r,
                 Xbar_sel => Xbar_sel_N_r,
                 RTS      => RTS_N_r
        );

    Arbiter_E : Arbiter
        PORT MAP(reset    => reset,
                 clk      => clk,
                 Req_N    => Req_NE,
                 Req_E    => '0',
                 Req_W    => Req_WE,
                 Req_S    => Req_SE,
                 Req_L    => Req_LE,
                 DCTS     => DCTS_E,
                 Grant_N  => Grant_EN_r,
                 Grant_E  => Grant_EE_r,
                 Grant_W  => Grant_EW_r,
                 Grant_S  => Grant_ES_r,
                 Grant_L  => Grant_EL_r,
                 Xbar_sel => Xbar_sel_E_r,
                 RTS      => RTS_E_r
        );

    Arbiter_W : Arbiter
        PORT MAP(reset    => reset,
                 clk      => clk,
                 Req_N    => Req_NW,
                 Req_E    => Req_EW,
                 Req_W    => '0',
                 Req_S    => Req_SW,
                 Req_L    => Req_LW,
                 DCTS     => DCTS_W,
                 Grant_N  => Grant_WN_r,
                 Grant_E  => Grant_WE_r,
                 Grant_W  => Grant_WW_r,
                 Grant_S  => Grant_WS_r,
                 Grant_L  => Grant_WL_r,
                 Xbar_sel => Xbar_sel_W_r,
                 RTS      => RTS_W_r
        );

    Arbiter_S : Arbiter
        PORT MAP(reset    => reset,
                 clk      => clk,
                 Req_N    => Req_NS,
                 Req_E    => Req_ES,
                 Req_W    => Req_WS,
                 Req_S    => '0',
                 Req_L    => Req_LS,
                 DCTS     => DCTS_S,
                 Grant_N  => Grant_SN_r,
                 Grant_E  => Grant_SE_r,
                 Grant_W  => Grant_SW_r,
                 Grant_S  => Grant_SS_r,
                 Grant_L  => Grant_SL_r,
                 Xbar_sel => Xbar_sel_S_r,
                 RTS      => RTS_S_r
        );

    Arbiter_L : Arbiter
        PORT MAP(reset    => reset,
                 clk      => clk,
                 Req_N    => Req_NL,
                 Req_E    => Req_EL,
                 Req_W    => Req_WL,
                 Req_S    => Req_SL,
                 Req_L    => Req_LL,
                 DCTS     => DCTS_L,
                 Grant_N  => Grant_LN_r,
                 Grant_E  => Grant_LE_r,
                 Grant_W  => Grant_LW_r,
                 Grant_S  => Grant_LS_r,
                 Grant_L  => Grant_LL_r,
                 Xbar_sel => Xbar_sel_L_r,
                 RTS      => RTS_L_r
        );

    Arbiter_RED : Arbiter
        PORT MAP(reset    => reset,
                 clk      => clk,
                 Req_N    => Req_AREDNX_rd,
                 Req_E    => Req_AREDEX_rd,
                 Req_W    => Req_AREDWX_rd,
                 Req_S    => Req_AREDSX_rd,
                 Req_L    => Req_AREDLX_rd,
                 DCTS     => DCTS_REDX_rd,
                 Grant_N  => Grant_AREDXN_rd,
                 Grant_E  => Grant_AREDXE_rd,
                 Grant_W  => Grant_AREDXW_rd,
                 Grant_S  => Grant_AREDXS_rd,
                 Grant_L  => Grant_AREDXL_rd,
                 Xbar_sel => Xbar_sel_AREDX_rd,
                 RTS      => RTS_REDX_rd
        );

    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------

    -- all the Xbars
    XBAR_N : XBAR generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(North_in => FIFO_D_out_N,
                 East_in  => FIFO_D_out_E,
                 West_in  => FIFO_D_out_W,
                 South_in => FIFO_D_out_S,
                 Local_in => FIFO_D_out_L,
                 sel      => Xbar_sel_N,
                 Data_out => TX_N_r);
                 --               Local_in => FIFO_D_out_L,
    XBAR_E : XBAR generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(North_in => FIFO_D_out_N,
                 East_in  => FIFO_D_out_E,
                 West_in  => FIFO_D_out_W,
                 South_in => FIFO_D_out_S,
                 Local_in => FIFO_D_out_L,
                 sel      => Xbar_sel_E,
                 Data_out => TX_E_r);
    XBAR_W : XBAR generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(North_in => FIFO_D_out_N,
                 East_in  => FIFO_D_out_E,
                 West_in  => FIFO_D_out_W,
                 South_in => FIFO_D_out_S,
                 Local_in => FIFO_D_out_L,
                 sel      => Xbar_sel_W,
                 Data_out => TX_W_r);
    XBAR_S : XBAR generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(North_in => FIFO_D_out_N,
                 East_in  => FIFO_D_out_E,
                 West_in  => FIFO_D_out_W,
                 South_in => FIFO_D_out_S,
                 Local_in => FIFO_D_out_L,
                 sel      => Xbar_sel_S,
                 Data_out => TX_S_r);
    XBAR_L : XBAR generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(North_in => FIFO_D_out_N,
                 East_in  => FIFO_D_out_E,
                 West_in  => FIFO_D_out_W,
                 South_in => FIFO_D_out_S,
                 Local_in => FIFO_D_out_L,
                 sel      => Xbar_sel_L,
                 Data_out => TX_L_r);
    XBAR_RED : XBAR generic map(DATA_WIDTH => DATA_WIDTH)
        PORT MAP(North_in => FIFO_D_out_N,
                 East_in  => FIFO_D_out_E,
                 West_in  => FIFO_D_out_W,
                 South_in => FIFO_D_out_S,
                 Local_in => FIFO_D_out_L,
                 sel      => Xbar_sel_XBRED_X_rd,
                 Data_out => TX_REDX_rd);

    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------

    -- all processes for redundancy
    REDUNDANT_FIFO : process (CTS_E_r, CTS_L_r, CTS_N_r, CTS_S_r, CTS_w_r, FIFO_D_out_E_r, FIFO_D_out_L_r, FIFO_D_out_N_r, FIFO_D_out_S_r, FIFO_D_out_W_r, empty_E_r, empty_L_r, empty_N_r, empty_S_r, empty_W_r) is
    begin
        --defaults
        RX_X_rd     <= (others => '0');
        DRTS_X_rd   <= '0';
        Grant_NX_rd <= '0';
        Grant_EX_rd <= '0';
        Grant_WX_rd <= '0';
        Grant_SX_rd <= '0';
        Grant_LX_rd <= '0';

        CTS_N <= CTS_N_r;
        CTS_E <= CTS_E_r;
        CTS_W <= CTS_W_r;
        CTS_S <= CTS_S_r;
        CTS_L <= CTS_L_r;

        empty_N <= empty_N_r;
        empty_E <= empty_E_r;
        empty_W <= empty_W_r;
        empty_S <= empty_S_r;
        empty_L <= empty_L_r;

        FIFO_D_out_N <= FIFO_D_out_N_r;
        FIFO_D_out_E <= FIFO_D_out_E_r;
        FIFO_D_out_W <= FIFO_D_out_W_r;
        FIFO_D_out_S <= FIFO_D_out_S_r;
        FIFO_D_out_L <= FIFO_D_out_L_r;

    -- if Fault_On_FIFO_N = '1' then
    --     RX_X_rd     <= RX_N;
    --     DRTS_X_rd   <= DRTS_N;
    --     Grant_NX_rd <= '0';
    --     Grant_EX_rd <= Grant_EN;
    --     Grant_WX_rd <= Grant_WN;
    --     Grant_SX_rd <= Grant_SN;
    --     Grant_LX_rd <= Grant_LN;
    --
    --     CTS_N        <= CTS_X_rd;
    --     empty_N      <= empty_X_rd;
    --     FIFO_D_out_N <= FIFO_D_out_X_rd;
    --
    -- elsif Fault_On_FIFO_E = '1' then
    --     RX_X_rd     <= RX_E;
    --     DRTS_X_rd   <= DRTS_E;
    --     Grant_NX_rd <= Grant_NE;
    --     Grant_EX_rd <= '0';
    --     Grant_WX_rd <= Grant_WE;
    --     Grant_SX_rd <= Grant_SE;
    --     Grant_LX_rd <= Grant_LE;
    --
    --     CTS_E        <= CTS_X_rd;
    --     empty_E      <= empty_X_rd;
    --     FIFO_D_out_E <= FIFO_D_out_X_rd;
    -- elsif Fault_On_FIFO_W = '1' then
    --     RX_X_rd     <= RX_W;
    --     DRTS_X_rd   <= DRTS_W;
    --     Grant_NX_rd <= Grant_NW;
    --     Grant_EX_rd <= Grant_EW;
    --     Grant_WX_rd <= '0';
    --     Grant_SX_rd <= Grant_SW;
    --     Grant_LX_rd <= Grant_LW;
    --
    --     CTS_W        <= CTS_X_rd;
    --     empty_W      <= empty_X_rd;
    --     FIFO_D_out_W <= FIFO_D_out_X_rd;
    -- elsif Fault_On_FIFO_S = '1' then
    --     RX_X_rd     <= RX_S;
    --     DRTS_X_rd   <= DRTS_S;
    --     Grant_NX_rd <= Grant_NS;
    --     Grant_EX_rd <= Grant_ES;
    --     Grant_WX_rd <= Grant_WS;
    --     Grant_SX_rd <= '0';
    --     Grant_LX_rd <= Grant_LS;
    --
    --     CTS_S        <= CTS_X_rd;
    --     empty_S      <= empty_X_rd;
    --     FIFO_D_out_S <= FIFO_D_out_X_rd;
    -- elsif Fault_On_FIFO_L = '1' then
    --     RX_X_rd     <= RX_L;
    --     DRTS_X_rd   <= DRTS_L;
    --     Grant_NX_rd <= Grant_NL;
    --     Grant_EX_rd <= Grant_EL;
    --     Grant_WX_rd <= Grant_WL;
    --     Grant_SX_rd <= Grant_SL;
    --     Grant_LX_rd <= '0';
    --
    --     CTS_L        <= CTS_X_rd;
    --     empty_L      <= empty_X_rd;
    --     FIFO_D_out_L <= FIFO_D_out_X_rd;
    -- else
    --     null;
    -- end if;
    end process REDUNDANT_FIFO;

    REDUNDANT_LBDR : process (Req_EE_r, Req_EL_r, Req_EN_r, Req_ES_r, Req_EW_r, Req_LE_r, Req_LL_r, Req_LN_r, Req_LS_r, Req_LW_r, Req_NE_r, Req_NL_r, Req_NN_r, Req_NS_r, Req_NW_r, Req_SE_r, Req_SL_r, Req_SN_r, Req_SS_r, Req_SW_r, Req_WE_r, Req_WL_r, Req_WN_r, Req_WS_r, Req_WW_r) is
    begin
        --defaults
        empty_X_rd                                                             <= '0';
        FIFO_D_out_X_rd(DATA_WIDTH - 1 downto DATA_WIDTH - 3)                  <= (others => '0');
        FIFO_D_out_X_rd(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19) <= (others => '0');

        Req_NN <= Req_NN_r;
        Req_NE <= Req_NE_r;
        Req_NW <= Req_NW_r;
        Req_NS <= Req_NS_r;
        Req_NL <= Req_NL_r;

        Req_EN <= Req_EN_r;
        Req_EE <= Req_EE_r;
        Req_EW <= Req_EW_r;
        Req_ES <= Req_ES_r;
        Req_EL <= Req_EL_r;

        Req_WN <= Req_WN_r;
        Req_WE <= Req_WE_r;
        Req_WW <= Req_WW_r;
        Req_WS <= Req_WS_r;
        Req_WL <= Req_WL_r;

        Req_SN <= Req_SN_r;
        Req_SE <= Req_SE_r;
        Req_SW <= Req_SW_r;
        Req_SS <= Req_SS_r;
        Req_SL <= Req_SL_r;

        Req_LN <= Req_LN_r;
        Req_LE <= Req_LE_r;
        Req_LW <= Req_LW_r;
        Req_LS <= Req_LS_r;
        Req_LL <= Req_LL_r;

    -- if Fault_On_LBDR_N = '1' then
    --     empty_X_rd                                                             <= empty_N;
    --     FIFO_D_out_X_rd(DATA_WIDTH - 1 downto DATA_WIDTH - 3)                  <= FIFO_D_out_N(DATA_WIDTH - 1 downto DATA_WIDTH - 3);
    --     FIFO_D_out_X_rd(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19) <= FIFO_D_out_N(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19);
    --
    --     Req_NN <= Req_XN_rd;
    --     Req_NE <= Req_XE_rd;
    --     Req_NW <= Req_XW_rd;
    --     Req_NS <= Req_XS_rd;
    --     Req_NL <= Req_XL_rd;
    --
    -- elsif Fault_On_LBDR_E = '1' then
    --     empty_X_rd                                                             <= empty_E;
    --     FIFO_D_out_X_rd(DATA_WIDTH - 1 downto DATA_WIDTH - 3)                  <= FIFO_D_out_E(DATA_WIDTH - 1 downto DATA_WIDTH - 3);
    --     FIFO_D_out_X_rd(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19) <= FIFO_D_out_E(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19);
    --
    --     Req_EN <= Req_XN_rd;
    --     Req_EE <= Req_XE_rd;
    --     Req_EW <= Req_XW_rd;
    --     Req_ES <= Req_XS_rd;
    --     Req_EL <= Req_XL_rd;
    --
    -- elsif Fault_On_LBDR_W = '1' then
    --     empty_X_rd                                                             <= empty_W;
    --     FIFO_D_out_X_rd(DATA_WIDTH - 1 downto DATA_WIDTH - 3)                  <= FIFO_D_out_W(DATA_WIDTH - 1 downto DATA_WIDTH - 3);
    --     FIFO_D_out_X_rd(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19) <= FIFO_D_out_W(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19);
    --
    --     Req_WN <= Req_XN_rd;
    --     Req_WE <= Req_XE_rd;
    --     Req_WW <= Req_XW_rd;
    --     Req_WS <= Req_XS_rd;
    --     Req_WL <= Req_XL_rd;
    --
    -- elsif Fault_On_LBDR_S = '1' then
    --     empty_X_rd                                                             <= empty_S;
    --     FIFO_D_out_X_rd(DATA_WIDTH - 1 downto DATA_WIDTH - 3)                  <= FIFO_D_out_S(DATA_WIDTH - 1 downto DATA_WIDTH - 3);
    --     FIFO_D_out_X_rd(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19) <= FIFO_D_out_S(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19);
    --
    --     Req_SN <= Req_XN_rd;
    --     Req_SE <= Req_XE_rd;
    --     Req_SW <= Req_XW_rd;
    --     Req_SS <= Req_XS_rd;
    --     Req_SL <= Req_XL_rd;
    --
    -- elsif Fault_On_LBDR_L = '1' then
    --     empty_X_rd                                                             <= empty_L;
    --     FIFO_D_out_X_rd(DATA_WIDTH - 1 downto DATA_WIDTH - 3)                  <= FIFO_D_out_L(DATA_WIDTH - 1 downto DATA_WIDTH - 3);
    --     FIFO_D_out_X_rd(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19) <= FIFO_D_out_L(DATA_WIDTH - 19 + NoC_size - 1 downto DATA_WIDTH - 19);
    --
    --     Req_LN <= Req_XN_rd;
    --     Req_LE <= Req_XE_rd;
    --     Req_LW <= Req_XW_rd;
    --     Req_LS <= Req_XS_rd;
    --     Req_LL <= Req_XL_rd;
    --
    -- else
    --     null;
    -- end if;
    end process REDUNDANT_LBDR;

   REDUNDANT_Arbiter : process (Grant_EE_r, Grant_EL_r, Grant_EN_r, Grant_ES_r, Grant_EW_r, Grant_LE_r, Grant_LL_r, Grant_LN_r, Grant_LS_r, Grant_LW_r, Grant_NE_r, Grant_NL_r, Grant_NN_r, Grant_NS_r, Grant_NW_r, Grant_SE_r, Grant_SL_r, Grant_SN_r, Grant_SS_r, Grant_SW_r, Grant_WE_r, Grant_WL_r, Grant_WN_r, Grant_WS_r, Grant_WW_r, RTS_E_r, RTS_L_r, RTS_N_r, RTS_S_r, RTS_W_r, Xbar_sel_E_r, Xbar_sel_L_r, Xbar_sel_N_r, Xbar_sel_S_r, Xbar_sel_W_r, Arbiter_Fault_Info(0), Arbiter_Fault_Info(1), Arbiter_Fault_Info(2), Arbiter_Fault_Info(3), Arbiter_Fault_Info(4), DCTS_E, DCTS_L, DCTS_N, DCTS_S, DCTS_w, Grant_AREDXE_rd, Grant_AREDXL_rd, Grant_AREDXN_rd, Grant_AREDXS_rd, Grant_AREDXW_rd, RTS_REDX_rd, Req_EL, Req_EN, Req_ES, Req_EW, Req_LE, Req_LN, Req_LS, Req_LW, Req_NE, Req_NL, Req_NS, Req_NW, Req_SE, Req_SL, Req_SN, Req_SW, Req_WE, Req_WL, Req_WN, Req_WS, Xbar_sel_AREDX_rd) is
    begin
        --defaults
        Req_AREDNX_rd <= '0';
        Req_AREDEX_rd <= '0';
        Req_AREDWX_rd <= '0';
        Req_AREDSX_rd <= '0';
        Req_AREDLX_rd <= '0';
        DCTS_REDX_rd  <= '0';

        Grant_NN   <= Grant_NN_r;
        Grant_NE   <= Grant_NE_r;
        Grant_NW   <= Grant_NW_r;
        Grant_NS   <= Grant_NS_r;
        Grant_NL   <= Grant_NL_r;
        Xbar_sel_N <= Xbar_sel_N_r;
        RTS_N      <= RTS_N_r;

        Grant_EN   <= Grant_EN_r;
        Grant_EE   <= Grant_EE_r;
        Grant_EW   <= Grant_EW_r;
        Grant_ES   <= Grant_ES_r;
        Grant_EL   <= Grant_EL_r;
        Xbar_sel_E <= Xbar_sel_E_r;
        RTS_E      <= RTS_E_r;

        Grant_WN   <= Grant_WN_r;
        Grant_WE   <= Grant_WE_r;
        Grant_WW   <= Grant_WW_r;
        Grant_WS   <= Grant_WS_r;
        Grant_WL   <= Grant_WL_r;
        Xbar_sel_W <= Xbar_sel_W_r;
        RTS_W      <= RTS_W_r;

        Grant_SN   <= Grant_SN_r;
        Grant_SE   <= Grant_SE_r;
        Grant_SW   <= Grant_SW_r;
        Grant_SS   <= Grant_SS_r;
        Grant_SL   <= Grant_SL_r;
        Xbar_sel_S <= Xbar_sel_S_r;
        RTS_S      <= RTS_S_r;

        Grant_LN   <= Grant_LN_r;
        Grant_LE   <= Grant_LE_r;
        Grant_LW   <= Grant_LW_r;
        Grant_LS   <= Grant_LS_r;
        Grant_LL   <= Grant_LL_r;
        Xbar_sel_L <= Xbar_sel_L_r;
        RTS_L      <= RTS_L_r;

     if Fault_On_Arbiter_N = '1' then
         Req_AREDNX_rd <= '0';
         Req_AREDEX_rd <= Req_EN;
         Req_AREDWX_rd <= Req_WN;
         Req_AREDSX_rd <= Req_SN;
         Req_AREDLX_rd <= Req_LN;
         DCTS_REDX_rd  <= DCTS_N;
         Grant_NN             <= Grant_AREDXN_rd;
         Grant_NE             <= Grant_AREDXE_rd;
         Grant_NW             <= Grant_AREDXW_rd;
         Grant_NS             <= Grant_AREDXS_rd;
         Grant_NL             <= Grant_AREDXL_rd;
         Xbar_sel_N           <= Xbar_sel_AREDX_rd;
         RTS_N                <= RTS_REDX_rd;

     elsif Fault_On_Arbiter_E = '1' then
         Req_AREDNX_rd <= Req_NE;
         Req_AREDEX_rd <= '0';
         Req_AREDWX_rd <= Req_WE;
         Req_AREDSX_rd <= Req_SE;
         Req_AREDLX_rd <= Req_LE;
         DCTS_REDX_rd  <= DCTS_E;
         Grant_EN             <= Grant_AREDXN_rd;
         Grant_EE             <= Grant_AREDXE_rd;
         Grant_EW             <= Grant_AREDXW_rd;
         Grant_ES             <= Grant_AREDXS_rd;
         Grant_EL             <= Grant_AREDXL_rd;
         Xbar_sel_E           <= Xbar_sel_AREDX_rd;
         RTS_E                <= RTS_REDX_rd;

     elsif Fault_On_Arbiter_W = '1' then
         Req_AREDNX_rd <= Req_NW;
         Req_AREDEX_rd <= Req_EW;
         Req_AREDWX_rd <= '0';
         Req_AREDSX_rd <= Req_SW;
         Req_AREDLX_rd <= Req_LW;
         DCTS_REDX_rd  <= DCTS_W;
         Grant_WN             <= Grant_AREDXN_rd;
         Grant_WE             <= Grant_AREDXE_rd;
         Grant_WW             <= Grant_AREDXW_rd;
         Grant_WS             <= Grant_AREDXS_rd;
         Grant_WL             <= Grant_AREDXL_rd;
         Xbar_sel_W           <= Xbar_sel_AREDX_rd;
         RTS_W                <= RTS_REDX_rd;

     elsif Fault_On_Arbiter_S = '1' then
         Req_AREDNX_rd <= Req_NS;
         Req_AREDEX_rd <= Req_ES;
         Req_AREDWX_rd <= Req_WS;
         Req_AREDSX_rd <= '0';
         Req_AREDLX_rd <= Req_LS;
         DCTS_REDX_rd  <= DCTS_S;
         Grant_SN             <= Grant_AREDXN_rd;
         Grant_SE             <= Grant_AREDXE_rd;
         Grant_SW             <= Grant_AREDXW_rd;
         Grant_SS             <= Grant_AREDXS_rd;
         Grant_SL             <= Grant_AREDXL_rd;
         Xbar_sel_S           <= Xbar_sel_AREDX_rd;
         RTS_S                <= RTS_REDX_rd;

     elsif Fault_On_Arbiter_L = '1' then
         Req_AREDNX_rd <= Req_NL;
         Req_AREDEX_rd <= Req_EL;
         Req_AREDWX_rd <= Req_WL;
         Req_AREDSX_rd <= Req_SL;
         Req_AREDLX_rd <= '0';
         DCTS_REDX_rd  <= DCTS_L;
         Grant_LN             <= Grant_AREDXN_rd;
         Grant_LE             <= Grant_AREDXE_rd;
         Grant_LW             <= Grant_AREDXW_rd;
         Grant_LS             <= Grant_AREDXS_rd;
         Grant_LL             <= Grant_AREDXL_rd;
         Xbar_sel_L           <= Xbar_sel_AREDX_rd;
         RTS_L                <= RTS_REDX_rd;
     else
         null;
     end if;
    end process REDUNDANT_Arbiter;

    REDUNDANT_Xbar : process (TX_E_r, TX_L_r, TX_N_r, TX_S_r, TX_W_r, TX_REDX_rd, Xbar_Fault_Info(0), Xbar_Fault_Info(1), Xbar_Fault_Info(2), Xbar_Fault_Info(3), Xbar_Fault_Info(4), Xbar_sel_E, Xbar_sel_L, Xbar_sel_N, Xbar_sel_S, Xbar_sel_W) is
    begin
        --defaults
        Xbar_sel_XBRED_X_rd <= (others => '0');
        TX_N                       <= TX_N_r;
        TX_E                       <= TX_E_r;
        TX_W                       <= TX_W_r;
        TX_S                       <= TX_S_r;
        TX_L                       <= TX_L_r;

     if Fault_On_Xbar_N = '1' then
         Xbar_sel_XBRED_X_rd <= Xbar_sel_N;
         TX_N                       <= TX_REDX_rd;
     elsif Fault_On_Xbar_E = '1' then
         Xbar_sel_XBRED_X_rd <= Xbar_sel_E;
         TX_E                       <= TX_REDX_rd;
     elsif Fault_On_Xbar_W = '1' then
         Xbar_sel_XBRED_X_rd <= Xbar_sel_W;
         TX_W                       <= TX_REDX_rd;
     elsif Fault_On_Xbar_S = '1' then
         Xbar_sel_XBRED_X_rd <= Xbar_sel_S;
         TX_S                       <= TX_REDX_rd;
     elsif Fault_On_Xbar_L = '1' then
         Xbar_sel_XBRED_X_rd <= Xbar_sel_L;
         TX_L                       <= TX_REDX_rd;
     else
         null;
     end if;
    end process REDUNDANT_Xbar;

end;
