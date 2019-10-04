-------------------------------------------------------------------------------
-- Descripcion:
--  Implementa un channelizer polifase receptor de N-canales
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rxchan is
				generic(
											 NCH                : natural := 16; --number of channels
											 AXIS_TDATA_WIDTH_I : natural := 32;
											 --AXIS_TDATA_WIDTH_O : natural := 48    
											 AXIS_TDATA_WIDTH_O : natural := 32    
							 );
				port ( 
										 aclk             : in  std_logic;
										 aresetn          : in  std_logic;
										 s_axis_tdata     : in  std_logic_vector (AXIS_TDATA_WIDTH_I-1 downto 0);
										 s_axis_tvalid    : in  std_logic;
										 s_axis_tready    : out std_logic;
										 s_axis_tlast     : in  std_logic;

										 --pragma translate off
										 --debug_fir_real   : out std_logic_vector(18 downto 0);
										 --debug_fir_imag   : out std_logic_vector(18 downto 0);
										 --debug_fir_valid  : out std_logic;
										 --pragma translate on

										 m_axis_tdata     : out  std_logic_vector (AXIS_TDATA_WIDTH_O-1 downto 0);
										 m_axis_tvalid    : out  std_logic;
										 m_axis_tlast     : out  std_logic;
										 m_axis_tready    : in   std_logic;
										 -- FIR interface
										 fir_m_axis_data_tvalid   : out std_logic;
										 fir_m_axis_data_tready   : in std_logic;
										 fir_m_axis_data_tlast    : out std_logic;
										 fir_m_axis_data_tdata    : out std_logic_vector(31 downto 0);
										 fir_m_axis_config_tvalid : out std_logic;
										 fir_m_axis_config_tready : in std_logic;
										 fir_m_axis_config_tlast  : out std_logic;
										 fir_m_axis_config_tdata  : out std_logic_vector(7 downto 0);
										 fir_s_axis_data_tvalid   : in std_logic;
										 fir_s_axis_data_tlast    : in std_logic;
										 fir_s_axis_data_tuser    : in std_logic_vector(4 downto 0);
										 fir_s_axis_data_tdata    : in std_logic_vector(47 downto 0);
										 event_tl_missing_fir     : in std_logic;
										 event_tl_unexpected_fir  : in std_logic;
										 event_cfg_tl_missing_fir : in std_logic;
										 event_cfg_tl_unexpected_fir : in std_logic;
										 --counter interface
										 cntr_ce : out std_logic;
										 cntr_load : out std_logic;
										 cntr_l : out std_logic_vector(5-1 downto 0);
										 cntr_q : in std_logic_vector(5-1 downto 0);
										 --MEMORY interface
										 mem_a        : out std_logic_vector(5-1 downto 0);
										 mem_d        : out std_logic_vector(33 downto 0);
										 mem_dpra     : out std_logic_vector(5-1 downto 0);
										 --mem_clk      : out std_logic;
										 mem_we       : out std_logic;
										 --mem_qdpo_clk : out std_logic;
										 mem_qdpo     : in std_logic_vector(33 downto 0);
										 -- IFFT interface
										 ifft_m_axis_config_tdata  : out std_logic_vector(7 downto 0);
										 ifft_m_axis_config_tvalid : out std_logic;
										 ifft_m_axis_config_tready : in std_logic;
										 ifft_m_axis_data_tdata    : out std_logic_vector(47 downto 0);
										 ifft_m_axis_data_tvalid   : out std_logic;
										 ifft_m_axis_data_tready   : in std_logic;
										 ifft_m_axis_data_tlast    : out std_logic;
										 ifft_s_axis_data_tdata    : in std_logic_vector(47 downto 0);
										 ifft_s_axis_data_tvalid   : in std_logic;
										 ifft_s_axis_data_tready   : out std_logic;
										 ifft_s_axis_data_tlast    : in std_logic;
										 event_frame_started_ifft  : in std_logic;
										 event_tl_unexpected_ifft : in std_logic;
										 event_tl_missing_ifft    : in std_logic;
										 event_status_channel_halt_ifft   : in std_logic;
										 event_data_in_channel_halt_ifft  : in std_logic;
										 event_data_out_channel_halt_ifft : in std_logic;
										 -- FIFO interface
										 fifo_m_axis_tvalid : out std_logic;
										 fifo_m_axis_tready : in std_logic;
										 fifo_m_axis_tdata  : out std_logic_vector(63 downto 0);
										 fifo_s_axis_tvalid : in std_logic;
										 fifo_s_axis_tlast  : in std_logic;
										 fifo_s_axis_tready : out std_logic;
										 fifo_s_axis_tdata  : in std_logic_vector(63 downto 0)
						 );
end rxchan;

architecture rtl of rxchan is

				signal s_fir_config_tdata  : std_logic_vector(7 downto 0):=std_logic_vector(to_unsigned(NCH-1,8));
				--  signal s_fir_tdata         : std_logic_vector(31 downto 0):=(others=>'0');
				signal m_fir_tdata         : std_logic_vector(47 downto 0):=(others=>'0');
				signal m_fir_chanid        : std_logic_vector(4 downto 0):=(others=>'0');
				signal mem_din,mem_dout   : std_logic_vector(33 downto 0):=(others=>'0');
				signal mem_wr_addr, mem_rd_addr   : std_logic_vector(5-1 downto 0):=(others=>'0');
				signal s_fft_read_addr            : std_logic_vector(3 downto 0):=(others=>'0');
				signal s_fft_tdata,	m_fft_tdata   : std_logic_vector(47 downto 0):=(others=>'0');
				signal s_fifo_tdata, m_fifo_tdata : std_logic_vector(63 downto 0):=(others=>'0');
				signal m_fir_config_tvalid,
				m_fir_config_tready,
				fir_config_complete,
				m_fir_tvalid,
				m_fir_tlast,
				m_fir_page,
				s_fft_tvalid,
				s_fft_tvalid_align,
				s_fft_start,
				s_fft_tready,
				m_fft_tvalid,
				m_fft_tready,
				reverse_addr_enable         : std_logic := '0';
				signal s_fft_page           : std_logic := '1';
				signal cntr_load_value      : std_logic_vector(5-1 downto 0);
--  signal reset_shreg                       : std_logic_vector(3 downto 0) := (others => '0');
--  signal reset_s                           : std_logic := '0';


begin

				-- Startup configuration for the FIR
				-- Selects which coefficient set to use for which interleaved channel
				i_startup_config: process(aclk)
				begin
								if (rising_edge(aclk)) then
												if m_fir_config_tready = '1' then 
																if m_fir_config_tvalid = '1' then 
																				-- This counts from NCH-1 to 0. This is the order in which 
																				-- coefficients are assigned to the interleaved channels
																				s_fir_config_tdata <= std_logic_vector(unsigned(s_fir_config_tdata) - 1);
																				if unsigned(s_fir_config_tdata) = 1 then
																								fir_config_complete <= '1';
																				end if;
																end if;
																m_fir_config_tvalid <= not fir_config_complete;
												end if;
								end if;
				end process;

				--  s_fir_tdata <= s_axis_data_tdata(AXIS_TDATA_WIDTH_I-1 downto AXIS_TDATA_WIDTH_I/2) & s_axis_data_tdata(AXIS_TDATA_WIDTH_I/2-1 downto 0);

				fir_m_axis_data_tvalid <= s_axis_tvalid;
				s_axis_tready <= fir_m_axis_data_tready; --open,
				fir_m_axis_data_tlast  <= s_axis_tlast; --'0', -- Ignore event
				fir_m_axis_data_tdata  <= s_axis_tdata; --fir_tdata,

				fir_m_axis_config_tvalid  <= m_fir_config_tvalid;
				m_fir_config_tready <= fir_m_axis_config_tready;
				fir_m_axis_config_tlast   <= '0'; -- Ignore event
				fir_m_axis_config_tdata   <= s_fir_config_tdata;

				m_fir_tvalid <= fir_s_axis_data_tvalid;  
				m_fir_tlast  <= fir_s_axis_data_tlast;   
				m_fir_chanid <= fir_s_axis_data_tuser;   
				m_fir_tdata  <= fir_s_axis_data_tdata;   

				--fir_event_s_data_tlast_missing => open,
				--fir_event_s_data_tlast_unexpected => open,
				--fir_event_s_config_tlast_missing => open,
				--fir_event_s_config_tlast_unexpected => open

				--pragma translate off
				--debug_fir_real  <= m_fir_tdata(18 downto 0);
				--debug_fir_imag  <= m_fir_tdata(42 downto 24);
				--debug_fir_valid <= m_fir_tvalid;
				--pragma translate on

				i_mem_page: process(aclk)
				begin
								if (rising_edge(aclk)) then
												if m_fir_tlast='1' and m_fir_tvalid='1' then
																m_fir_page <= not m_fir_page;
																s_fft_page <= not s_fft_page;
												end if;
								end if;
				end process;

				mem_din     <= m_fir_tdata(42 downto 26) & m_fir_tdata(18 downto 2);
				mem_wr_addr <= m_fir_page & m_fir_chanid(4 downto 1);
				mem_rd_addr <= s_fft_page & s_fft_read_addr;

				mem_d       <= mem_din;
				mem_a       <= mem_wr_addr;
				mem_we      <= m_fir_tvalid;
				--mem_clk      => aclk,

				mem_dpra     <= mem_rd_addr;
				--mem_qdpo_clk <= aclk,
				mem_dout <= mem_qdpo;

				s_fft_tdata(16 downto 0)  <= mem_dout(16 downto 0);
				s_fft_tdata(40 downto 24) <= mem_dout(33 downto 17);

				s_fft_start         <= m_fir_tvalid and m_fir_tlast;
				-- Places a LUT on the CE port, can be a slow path
				reverse_addr_enable <= s_fft_start or s_fft_tvalid;

				cntr_load_value <= (others => '1');
												 --clk           => aclk;
				cntr_ce            <= reverse_addr_enable;
				cntr_load          <= s_fft_start;
				cntr_l             <= cntr_load_value; --"1111",
																							 --    q(ADDR_SIZE-2 downto 0) => s_fft_read_addr,
																							 --    q(ADDR_SIZE-1)          => s_fft_tvalid
				s_fft_read_addr <= cntr_q(5-2 downto 0);
				s_fft_tvalid    <= cntr_q(5-1);

				i_fft_tvalid_align: process(aclk)
				begin
								if (rising_edge(aclk)) then
												s_fft_tvalid_align <= s_fft_tvalid;
								end if;
				end process;

				--aclk => aclk,
				--aresetn => aresetn,
				ifft_m_axis_config_tdata <= "00000000"; -- FWD/inV(bit 0) 0 = Inverse FFT
				ifft_m_axis_config_tvalid <= s_fft_tready; --'1';
				s_fft_tready <= ifft_m_axis_config_tready;

				ifft_m_axis_data_tdata <= s_fft_tdata;
				ifft_m_axis_data_tvalid <= s_fft_tvalid_align;
				--ifft_m_axis_data_tready => open;
				ifft_m_axis_data_tlast <= '0'; -- Ignore event

				m_fft_tdata <= ifft_s_axis_data_tdata;
				m_fft_tvalid <= ifft_s_axis_data_tvalid;
				ifft_s_axis_data_tready <= m_fft_tready;
				--ifft_s_axis_data_tlast => open,

				--ifft_event_frame_started => open,
				--ifft_event_tlast_unexpected => open,
				--ifft_event_tlast_missing => open,
				--ifft_event_status_channel_halt => open,
				--ifft_event_data_in_channel_halt => open,
				--ifft_event_data_out_channel_halt => open

				s_fifo_tdata(47 downto 0) <= m_fft_tdata;

				--  startup_reset_gen_p: process(aclk)
				--  begin
				--    if (rising_edge(aclk)) then
				--      reset_shreg <= reset_shreg(reset_shreg'left-1 downto 0) & '1';
				--      reset_s     <= reset_shreg(reset_shreg'left);
				--    end if;
				--  end process;


				fifo_m_axis_tvalid <= m_fft_tvalid;
				m_fft_tready <= fifo_m_axis_tready;
				fifo_m_axis_tdata  <= s_fifo_tdata;

				m_axis_tvalid <= fifo_s_axis_tvalid; 
				m_axis_tlast  <= fifo_s_axis_tlast; 
				fifo_s_axis_tready <= m_axis_tready;
				m_fifo_tdata <= fifo_s_axis_tdata;

				--m_axis_tdata <= m_fifo_tdata(AXIS_TDATA_WIDTH_O-1 downto 0);
				m_axis_tdata <= m_fifo_tdata(39 downto 24) & m_fifo_tdata(15 downto 0);

end rtl;

