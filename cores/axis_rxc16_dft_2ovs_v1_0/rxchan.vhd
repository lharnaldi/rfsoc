-------------------------------------------------------------------------------
-- Descripcion:
--  Implementa un channelizer polifase receptor de N-canales
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;

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

										 dbg_fir0_real    : out std_logic_vector(18 downto 0);
										 dbg_fir0_imag    : out std_logic_vector(18 downto 0);
										 dbg_fir0_valid   : out std_logic;
										 dbg_fir1_real    : out std_logic_vector(18 downto 0);
										 dbg_fir1_imag    : out std_logic_vector(18 downto 0);
										 dbg_fir1_valid   : out std_logic;

										 m_axis_tdata     : out  std_logic_vector (AXIS_TDATA_WIDTH_O-1 downto 0);
										 m_axis_tvalid    : out  std_logic;
										 m_axis_tlast     : out  std_logic;
										 m_axis_tready    : in   std_logic);
end rxchan;

architecture rtl of rxchan is

				constant C_ADDR_SIZE : natural := log2c(NCH); --counter addr_size
				constant M_ADDR_SIZE : natural := log2c(2*NCH); --memory addr_size

				component shift_register is
								generic(
															 N: integer := 32; --data length
															 M: integer := 8   --M shifts
											 );
								port (
														 aclk   : in  std_logic;
														 aresetn: in  std_logic;
														 en     : in  std_logic;
														 data_i : in  std_logic_vector(N-1 downto 0);
														 data_o : out std_logic_vector(N-1 downto 0)
										 );
				end component;

				-- FIR0 block
				component rx_fir0
								port (
														 aclk               : in std_logic;
														 aclken             : in std_logic;
														 aresetn            : in std_logic;
														 s_axis_data_tvalid : in std_logic;
														 s_axis_data_tready : out std_logic;
														 s_axis_data_tlast  : in std_logic;
														 s_axis_data_tdata  : in std_logic_vector(31 downto 0);
														 s_axis_config_tvalid : in std_logic;
														 s_axis_config_tready : out std_logic;
														 s_axis_config_tlast : in std_logic;
														 s_axis_config_tdata : in std_logic_vector(7 downto 0);
														 m_axis_data_tvalid  : out std_logic;
												     --m_axis_data_tready  : in std_logic;
														 m_axis_data_tlast   : out std_logic;
														 m_axis_data_tuser   : out std_logic_vector(4-1 downto 0);
														 m_axis_data_tdata   : out std_logic_vector(47 downto 0);
														 event_s_data_tlast_missing : out std_logic;
														 event_s_data_tlast_unexpected : out std_logic;
														 event_s_config_tlast_missing : out std_logic;
														 event_s_config_tlast_unexpected : out std_logic
										 );
				end component;
				-- FIR1 block
				component rx_fir1
								port (
														 aclk               : in std_logic;
														 aclken             : in std_logic;
														 aresetn            : in std_logic;
														 s_axis_data_tvalid : in std_logic;
														 s_axis_data_tready : out std_logic;
														 s_axis_data_tlast  : in std_logic;
														 s_axis_data_tdata  : in std_logic_vector(31 downto 0);
														 s_axis_config_tvalid : in std_logic;
														 s_axis_config_tready : out std_logic;
														 s_axis_config_tlast : in std_logic;
														 s_axis_config_tdata : in std_logic_vector(7 downto 0);
														 m_axis_data_tvalid  : out std_logic;
												     --m_axis_data_tready  : in std_logic;
														 m_axis_data_tlast   : out std_logic;
														 m_axis_data_tuser   : out std_logic_vector(4-1 downto 0);
														 m_axis_data_tdata   : out std_logic_vector(47 downto 0);
														 event_s_data_tlast_missing : out std_logic;
														 event_s_data_tlast_unexpected : out std_logic;
														 event_s_config_tlast_missing : out std_logic;
														 event_s_config_tlast_unexpected : out std_logic
										 );
				end component;

				component fifo0
								port (
														 s_aclk        : in std_logic;
														 s_aclk_en     : in std_logic;
														 s_aresetn     : in std_logic;
														 s_axis_tvalid : in std_logic;
														 s_axis_tlast  : in std_logic;
														 s_axis_tready : out std_logic;
														 s_axis_tdata  : in std_logic_vector(63 downto 0);
														 m_axis_tvalid : out std_logic;
														 m_axis_tlast  : out std_logic;
														 m_axis_tready : in std_logic;
														 m_axis_tdata  : out std_logic_vector(63 downto 0)
										 );
				end component;

				component fifo1
								port (
														 s_aclk        : in std_logic;
														 s_aclk_en     : in std_logic;
														 s_aresetn     : in std_logic;
														 s_axis_tvalid : in std_logic;
														 s_axis_tlast  : in std_logic;
														 s_axis_tready : out std_logic;
														 s_axis_tdata  : in std_logic_vector(63 downto 0);
														 m_axis_tvalid : out std_logic;
														 m_axis_tlast  : out std_logic;
														 m_axis_tready : in std_logic;
														 m_axis_tdata  : out std_logic_vector(63 downto 0)
										 );
				end component;

				component clk_divN 
								generic(
															 N : natural := 8
											 );
								port (
														 aclk    : in std_logic;
														 aresetn : in std_logic;
														 en      : in std_logic;
														 div_N   : out std_logic
										 );      
				end component;

				component mux_2x1
								generic (
																N    : natural := 32
												);
								port (
								data0_i, data1_i   : in std_logic_vector(N-1 downto 0);
								sel                : in std_logic;
								ready_i            : in std_logic;
								ready0_o           : out std_logic;
								ready1_o           : out std_logic;
								valid0_i, valid1_i : in std_logic;
								valid_o            : out std_logic;
								data_o             : out std_logic_vector(N-1 downto 0)
				);
				end component;

				--component axis_mux_2x1 
				--				generic (
				--												N    : natural := 32
				--								);
				--				port (
				--										 aclk          : in std_logic;
				--										 aresetn       : in std_logic;

				--										 sel           : in std_logic;

				--										 s_axis_tdata0 : in std_logic_vector(N-1 downto 0);
				--										 s_axis_tvalid0: in std_logic;
				--										 s_axis_tready0: out std_logic;

				--										 s_axis_tdata1 : in std_logic_vector(N-1 downto 0);
				--										 s_axis_tvalid1: in std_logic;
				--										 s_axis_tready1: out std_logic;

				--										 m_axis_tdata  : out std_logic_vector(N-1 downto 0);
				--										 m_axis_tvalid : out std_logic;
				--										 m_axis_tready : in std_logic
				--						 );
				--end component;

				-- FFT block
				component rx_fft
								port (
														 aclk    : in std_logic;
														 aresetn : in std_logic;
														 s_axis_config_tdata : in std_logic_vector(7 downto 0);
														 s_axis_config_tvalid : in std_logic;
														 s_axis_config_tready : out std_logic;
														 s_axis_data_tdata : in std_logic_vector(47 downto 0);
														 s_axis_data_tvalid : in std_logic;
														 s_axis_data_tready : out std_logic;
														 s_axis_data_tlast : in std_logic;
														 m_axis_data_tdata : out std_logic_vector(47 downto 0);
														 m_axis_data_tvalid : out std_logic;
														 m_axis_data_tready : in std_logic;
														 m_axis_data_tlast : out std_logic;
														 event_frame_started : out std_logic;
														 event_tlast_unexpected : out std_logic;
														 event_tlast_missing : out std_logic;
														 event_status_channel_halt : out std_logic;
														 event_data_in_channel_halt : out std_logic;
														 event_data_out_channel_halt : out std_logic
										 );
				end component;

				-- Output FIFO to spread out the block based output of the FFT
				component rx_fifo
								port (
														 s_aclk        : in std_logic;
														 s_aresetn     : in std_logic;
														 s_axis_tvalid : in std_logic;
														 s_axis_tlast  : in std_logic;
														 s_axis_tready : out std_logic;
														 s_axis_tdata  : in std_logic_vector(63 downto 0);
														 m_axis_tvalid : out std_logic;
														 m_axis_tlast  : out std_logic;
														 m_axis_tready : in std_logic;
														 m_axis_tdata  : out std_logic_vector(63 downto 0)
										 );
				end component;

				signal s_fir_config_tdata  : std_logic_vector(7 downto 0):= "00000001"; --(others => '0');
				--  signal s_fir_tdata         : std_logic_vector(31 downto 0):=(others=>'0');
				signal m_fir_tdata         : std_logic_vector(47 downto 0):=(others=>'0');
				signal m_fir_chanid        : std_logic_vector(4 downto 0):=(others=>'0');
				signal mem_din,mem_dout   : std_logic_vector(33 downto 0):=(others=>'0');
				signal mem_wr_addr, mem_rd_addr   : std_logic_vector(5-1 downto 0):=(others=>'0');
				signal s_fft_read_addr            : std_logic_vector(3 downto 0):=(others=>'0');
				signal s_fft_tdata,	m_fft_tdata   : std_logic_vector(47 downto 0):=(others=>'0');
				signal s_fifo_tdata, m_fifo_tdata : std_logic_vector(63 downto 0):=(others=>'0');
				signal s_fir_config_tvalid,
				s_fir_config_tready,
				fir_config_complete,
				m_fir_tvalid,
				m_fir_tlast,
				m_fir_page,
				s_fft_tvalid,
				s_fft_tvalid_align,
				s_fft_start,
				s_fft_tready,
				m_fft_tvalid,
				m_fft_tlast,
				m_fft_tready,
				reverse_addr_enable         : std_logic := '0';
				signal s_fft_page           : std_logic := '1';
				signal cntr_load_value      : std_logic_vector(5-1 downto 0);
				signal fir_tready           : std_logic;
				signal s_fir0_tdata         : std_logic_vector(AXIS_TDATA_WIDTH_I-1 downto 0);
				signal fir_sel              : std_logic;
				signal fir0_tready, fir1_tready : std_logic;
				signal m_fir0_tvalid, m_fir0_tready, m_fir0_tlast : std_logic;
				signal m_fir1_tvalid, m_fir1_tready, m_fir1_tlast : std_logic;
				signal m_fir0_tdata, m_fir1_tdata    : std_logic_vector(48-1 downto 0);
				signal m_fifo0_tvalid, m_fifo0_tlast : std_logic;
				signal m_fifo1_tvalid, m_fifo1_tlast : std_logic;
				signal m_fifo0_tready, m_fifo1_tready: std_logic;
				signal m_fifo0_tdata, m_fifo1_tdata  : std_logic_vector(64-1 downto 0) := (others => '0');
				signal m_fifo00_tdata, m_fifo11_tdata : std_logic_vector(48-1 downto 0) := (others => '0');
				signal fft_tdata              : std_logic_vector(48-1 downto 0);
				signal fft_tvalid, fft_tready : std_logic;  
				signal s_fir_valid, div_en    : std_logic := '0';  
				signal tready_r, tready_n     : std_logic;  
				signal tvalid_r, tvalid_n     : std_logic;  
				signal fir_en                 : std_logic;  

begin

				-- Startup configuration for the FIRs
				-- Selects which coefficient set to use for which interleaved channel
				i_startup_config: process(aclk)
				begin
								if (rising_edge(aclk)) then
												if s_fir_config_tready = '1' then 
																if s_fir_config_tvalid = '1' then 
																				-- This counts from 0 to NCH-1. This is the order in which 
																				-- coefficients are assigned to the interleaved channels
																				s_fir_config_tdata <= std_logic_vector(unsigned(s_fir_config_tdata) + 1);
																				if unsigned(s_fir_config_tdata) = 7 then
																								fir_config_complete <= '1';
																				end if;
																end if;
																s_fir_config_tvalid <= not fir_config_complete;
												end if;
								end if;
				end process;

				process(aclk)
				begin
								if rising_edge(aclk) then
												if aresetn = '0' then
																tready_r <= '0';
																tvalid_r <= '0';
												else
																tready_r <= tready_n;
																tvalid_r <= tvalid_n;
												end if;
								end if;
				end process;
				tready_n <= '1' when (fir0_tready = '1' and fir1_tready = '1' and fir_config_complete = '1') else '0'; --wait for config to complete
				--s_axis_tready <= '1' when (fir0_tready = '1' and fir1_tready = '1' and fir_config_complete = '1') else '0'; --wait for config to complete
				s_axis_tready <= tready_r;

				tvalid_n <= '1' when (fir_config_complete = '1' and s_axis_tvalid = '1') else '0'; --wait for config to complete
				--s_fir_valid   <= '1' when (fir_config_complete = '1' and s_axis_tvalid = '1') else '0'; --wait for config to complete
				s_fir_valid <= tvalid_r;

				i_dly: shift_register
				generic map(
													 N => 32,
													 M => 8
									 )
				port map(
												aclk    => aclk,
												aresetn => aresetn,
												en      => tready_r,
												data_i  => s_axis_tdata,
												data_o  => s_fir0_tdata
								);

				i_clkdiv: clk_divN
				        generic map(
																	 N => 1
													 )
								port map(
								aclk    => aclk,																											                        
								aresetn	=> aresetn,
								en      => '1',
								div_N 	=> fir_en
				);

				i_fir0: rx_fir0
				port map (
												 aclk => aclk,
												 aclken => fir_en,
												 aresetn => aresetn,
												 s_axis_data_tvalid => s_fir_valid, --s_axis_tvalid,
												 s_axis_data_tready => fir0_tready, --s_axis_tready, --open,
												 s_axis_data_tlast  => '0', -- Ignore event
												 s_axis_data_tdata  => s_fir0_tdata, --s_axis_tdata, --fir_tdata,

												 s_axis_config_tvalid  => s_fir_config_tvalid,
												 s_axis_config_tready  => s_fir_config_tready,
												 s_axis_config_tlast   => '0', -- Ignore event
												 s_axis_config_tdata   => s_fir_config_tdata,

												 m_axis_data_tvalid => m_fir0_tvalid,
												 --m_axis_data_tready => m_fir0_tready,
												 m_axis_data_tlast  => m_fir0_tlast,
												 m_axis_data_tuser  => open, --m_fir0_chanid,
												 m_axis_data_tdata  => m_fir0_tdata,

												 event_s_data_tlast_missing => open,
												 event_s_data_tlast_unexpected => open,
												 event_s_config_tlast_missing => open,
												 event_s_config_tlast_unexpected => open
								 );

				i_fir1: rx_fir1
				port map (
												 aclk => aclk,
												 aclken => fir_en,
												 aresetn => aresetn,
												 s_axis_data_tvalid => s_fir_valid, --s_axis_tvalid,
												 s_axis_data_tready => fir1_tready, --s_axis_tready, --open,
												 s_axis_data_tlast  => s_axis_tlast, --'0', -- Ignore event
												 s_axis_data_tdata  => s_axis_tdata, --fir_tdata,

												 s_axis_config_tvalid  => s_fir_config_tvalid,
												 s_axis_config_tready  => s_fir_config_tready,
												 s_axis_config_tlast   => '0', -- Ignore event
												 s_axis_config_tdata   => s_fir_config_tdata,

												 m_axis_data_tvalid => m_fir1_tvalid,
												 --m_axis_data_tready => m_fir1_tready,
												 m_axis_data_tlast  => m_fir1_tlast,
												 m_axis_data_tuser  => open, --m_fir1_chanid,
												 m_axis_data_tdata  => m_fir1_tdata,

												 event_s_data_tlast_missing => open,
												 event_s_data_tlast_unexpected => open,
												 event_s_config_tlast_missing => open,
												 event_s_config_tlast_unexpected => open
								 );

				dbg_fir0_real  <= m_fir0_tdata(18 downto 0);
				dbg_fir0_imag  <= m_fir0_tdata(42 downto 24);
				dbg_fir0_valid <= m_fir0_tvalid;
				dbg_fir1_real  <= m_fir1_tdata(18 downto 0);
				dbg_fir1_imag  <= m_fir1_tdata(42 downto 24);
				dbg_fir1_valid <= m_fir1_tvalid;

				--FIFOs
				i_fifo0: fifo0
				port map (
												 s_aclk        => aclk,
												 s_aclk_en     => fir_en,
												 s_aresetn     => aresetn, --reset_s, --'1',

												 s_axis_tvalid => m_fir0_tvalid,
												 s_axis_tready => m_fir0_tready,
												 s_axis_tlast  => m_fir0_tlast,
												 s_axis_tdata(48-1 downto 0)  => m_fir0_tdata,
												 s_axis_tdata(64-1 downto 48)  => (others => '0'), 

												 m_axis_tvalid => m_fifo0_tvalid, 
												 m_axis_tready => m_fifo0_tready,
												 m_axis_tlast  => m_fifo0_tlast,
												 m_axis_tdata  => m_fifo0_tdata
								 );

				i_fifo1: fifo1
				port map (
												 s_aclk        => aclk,
												 s_aclk_en     => fir_en,
												 s_aresetn     => aresetn, --reset_s, --'1',

												 s_axis_tvalid => m_fir1_tvalid,
												 s_axis_tready => m_fir1_tready,
												 s_axis_tlast  => m_fir1_tlast,
												 s_axis_tdata(48-1 downto 0)  => m_fir1_tdata,
												 s_axis_tdata(64-1 downto 48)  => (others => '0'), 

												 m_axis_tvalid => m_fifo1_tvalid, 
												 m_axis_tready => m_fifo1_tready,
												 m_axis_tlast  => m_fifo1_tlast,
												 m_axis_tdata  => m_fifo1_tdata
								 );

				div_en <= '1' when m_fifo0_tvalid = '1' or m_fifo1_tvalid = '1' else '0'; --FIXME: check this
				--register for clk divider x8
				i_divN: clk_divN 
				generic map(
													 N => 8
									 )
				port map(
												aclk    => aclk,
												aresetn => aresetn,
												en      => div_en,
												div_N   => fir_sel
								);

				--s_fft_tdata(16 downto 0)  <= m_fir_tdata(18 downto 2);
				--s_fft_tdata(40 downto 24) <= m_fir_tdata(42 downto 26);
				m_fifo00_tdata(16 downto 0)  <= m_fifo0_tdata(18 downto 2); --real
				m_fifo00_tdata(40 downto 24) <= m_fifo0_tdata(42 downto 26); --imaginary
				m_fifo11_tdata(16 downto 0)  <= m_fifo1_tdata(18 downto 2);  --real
				m_fifo11_tdata(40 downto 24) <= m_fifo1_tdata(42 downto 26);   --imaginary

				i_selector: mux_2x1
				generic map ( 
														N => 48
										)
				port map(
												data0_i => m_fifo00_tdata,
												data1_i => m_fifo11_tdata,
												sel     => fir_sel,
												ready_i => fft_tready,
												ready0_o => m_fifo0_tready,
												ready1_o => m_fifo1_tready,
												valid0_i=> m_fifo0_tvalid,
												valid1_i=> m_fifo1_tvalid,
												valid_o => fft_tvalid,
												data_o  => fft_tdata
								);

--i_selector: axis_mux_2x1
--generic map ( 
--										N => 48
--						)
--port map(
--								aclk          => aclk,
--								aresetn       => aresetn,

--								sel           => fir_sel,

--								s_axis_tdata0 => m_fifo00_tdata,
--								s_axis_tvalid0 => m_fifo0_tvalid,
--								s_axis_tready0 => m_fifo0_tready,

--								s_axis_tdata1 => m_fifo11_tdata,
--								s_axis_tvalid1 => m_fifo1_tvalid,
--								s_axis_tready1 => m_fifo1_tready,

--								m_axis_tdata   => fft_tdata,
--								m_axis_tvalid  => fft_tvalid,
--								m_axis_tready  => fft_tready
--				);

				i_fft: rx_fft
				port map (
												 aclk => aclk,
												 aresetn => aresetn,
												 s_axis_config_tdata => "00000001", -- FWD/inV(bit 0) 0 = Inverse FFT
												 s_axis_config_tvalid => '1',
												 s_axis_config_tready => s_fft_tready,

												 s_axis_data_tdata => fft_tdata, --s_fft_tdata,
												 s_axis_data_tvalid => fft_tvalid, --m_fir_tvalid, --s_fft_tvalid_align,
												 s_axis_data_tready => fft_tready, --open,
												 s_axis_data_tlast => '0', -- Ignore event

												 m_axis_data_tdata => m_fft_tdata,
												 m_axis_data_tvalid => m_fft_tvalid,
												 m_axis_data_tready => m_fft_tready,
												 m_axis_data_tlast => m_fft_tlast,

												 event_frame_started => open,
												 event_tlast_unexpected => open,
												 event_tlast_missing => open,
												 event_status_channel_halt => open,
												 event_data_in_channel_halt => open,
												 event_data_out_channel_halt => open
								 );

				s_fifo_tdata(47 downto 0) <= m_fft_tdata;

				i_fifo: rx_fifo
				port map (
												 s_aclk        => aclk,
												 s_aresetn     => aresetn, --reset_s, --'1',

												 s_axis_tvalid => m_fft_tvalid,
												 s_axis_tready => m_fft_tready,
												 s_axis_tlast  => m_fft_tlast,
												 s_axis_tdata  => s_fifo_tdata,

												 m_axis_tvalid => m_axis_tvalid, 
												 m_axis_tready => m_axis_tready,
												 m_axis_tlast  => m_axis_tlast,
												 m_axis_tdata  => m_fifo_tdata
								 );

				m_axis_tdata <= m_fifo_tdata(42 downto 27) & m_fifo_tdata(18 downto 3);

end rtl;

