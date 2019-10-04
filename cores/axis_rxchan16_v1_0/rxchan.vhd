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
											 AXIS_TDATA_WIDTH_O : natural := 48    
							 );
				port ( 
										 aclk             : in  std_logic;
										 aresetn          : in  std_logic;
										 s_axis_tdata     : in  std_logic_vector (AXIS_TDATA_WIDTH_I-1 downto 0);
										 s_axis_tvalid    : in  std_logic;
										 s_axis_tready    : out std_logic;
										 s_axis_tlast     : in  std_logic;

										 --pragma translate off
										 debug_fir_real   : out std_logic_vector(18 downto 0);
										 debug_fir_imag   : out std_logic_vector(18 downto 0);
										 debug_fir_valid  : out std_logic;
										 --pragma translate on

										 m_axis_tdata     : out  std_logic_vector (AXIS_TDATA_WIDTH_O-1 downto 0);
										 m_axis_tvalid    : out  std_logic;
										 m_axis_tready    : in   std_logic);
end rxchan;

architecture rtl of rxchan is

				function clogb2 (value: natural) return natural is
				variable temp    : natural := value;
				variable ret_val : natural := 1;
				begin
								while temp > 1 loop
												ret_val := ret_val + 1;
												temp    := temp / 2;
								end loop;
								return ret_val;
				end function;

				constant C_ADDR_SIZE : natural := clogb2(NCH); --counter addr_size
				constant M_ADDR_SIZE : natural := clogb2(2*NCH); --memory addr_size

				-- FIR block
				component rx_fir
								port (
														 aclk               : in std_logic;
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
														 m_axis_data_tlast   : out std_logic;
														 m_axis_data_tuser   : out std_logic_vector(4 downto 0);
														 m_axis_data_tdata   : out std_logic_vector(47 downto 0);
														 event_s_data_tlast_missing : out std_logic;
														 event_s_data_tlast_unexpected : out std_logic;
														 event_s_config_tlast_missing : out std_logic;
														 event_s_config_tlast_unexpected : out std_logic
										 );
				end component;

				-- Memory to buffer the sample based output of the FIR and flip the channel 
				-- order before the block based input of the FFT 
				-- The receiver requires a different commutator direction to the transmitter 
				-- and this implmented by flipping the channel order using this buffer
				component rx_mem
								port (
														 a        : in std_logic_vector(5-1 downto 0);
														 d        : in std_logic_vector(33 downto 0);
														 dpra     : in std_logic_vector(5-1 downto 0);
														 clk      : in std_logic;
														 we       : in std_logic;
														 qdpo_clk : in std_logic;
														 qdpo     : out std_logic_vector(33 downto 0)
										 );
				end component;

				-- Read address counter to reverse the channel order
				component reverse_addr
								port (
														 clk : in std_logic;
														 ce : in std_logic;
														 load : in std_logic;
														 --    l : in std_logic_vector(C_ADDR_SIZE-1 downto 0);
														 --    q : out std_logic_vector(C_ADDR_SIZE-1 downto 0)
														 l : in std_logic_vector(5-1 downto 0);
														 q : out std_logic_vector(5-1 downto 0)
										 );
				end component;

				-- IFFT block
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
														 s_aclk    : in std_logic;
														 s_aresetn : in std_logic;
														 s_axis_tvalid : in std_logic;
														 s_axis_tready : out std_logic;
														 s_axis_tdata : in std_logic_vector(63 downto 0);
														 m_axis_tvalid : out std_logic;
														 m_axis_tready : in std_logic;
														 m_axis_tdata : out std_logic_vector(63 downto 0)
										 );
				end component;

				signal s_fir_config_tdata  : std_logic_vector(7 downto 0):=std_logic_vector(to_unsigned(NCH-1,8));
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
												if s_fir_config_tready = '1' then 
																if s_fir_config_tvalid = '1' then 
																				-- This counts from NCH-1 to 0. This is the order in which 
																				-- coefficients are assigned to the interleaved channels
																				s_fir_config_tdata <= std_logic_vector(unsigned(s_fir_config_tdata) - 1);
																				if unsigned(s_fir_config_tdata) = 1 then
																								fir_config_complete <= '1';
																				end if;
																end if;
																s_fir_config_tvalid <= not fir_config_complete;
												end if;
								end if;
				end process;

				--  s_fir_tdata <= s_axis_data_tdata(AXIS_TDATA_WIDTH_I-1 downto AXIS_TDATA_WIDTH_I/2) & s_axis_data_tdata(AXIS_TDATA_WIDTH_I/2-1 downto 0);

				i_fir: rx_fir
				port map (
												 aclk => aclk,
												 aresetn => aresetn,
												 s_axis_data_tvalid => s_axis_tvalid,
												 s_axis_data_tready => s_axis_tready, --open,
												 s_axis_data_tlast  => s_axis_tlast, --'0', -- Ignore event
												 s_axis_data_tdata  => s_axis_tdata, --fir_tdata,

												 s_axis_config_tvalid  => s_fir_config_tvalid,
												 s_axis_config_tready  => s_fir_config_tready,
												 s_axis_config_tlast   => '0', -- Ignore event
												 s_axis_config_tdata   => s_fir_config_tdata,

												 m_axis_data_tvalid => m_fir_tvalid,
												 m_axis_data_tlast  => m_fir_tlast,
												 m_axis_data_tuser  => m_fir_chanid,
												 m_axis_data_tdata  => m_fir_tdata,

												 event_s_data_tlast_missing => open,
												 event_s_data_tlast_unexpected => open,
												 event_s_config_tlast_missing => open,
												 event_s_config_tlast_unexpected => open
								 );

				--pragma translate off
				debug_fir_real  <= m_fir_tdata(18 downto 0);
				debug_fir_imag  <= m_fir_tdata(42 downto 24);
				debug_fir_valid <= m_fir_tvalid;
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

				i_reverse_mem: rx_mem
				port map (
												 d        => mem_din,
												 a        => mem_wr_addr,
												 we       => m_fir_tvalid,
												 clk      => aclk,

												 dpra     => mem_rd_addr,
												 qdpo_clk => aclk,
												 qdpo     => mem_dout
								 );

				s_fft_tdata(16 downto 0)  <= mem_dout(16 downto 0);
				s_fft_tdata(40 downto 24) <= mem_dout(33 downto 17);

				s_fft_start         <= m_fir_tvalid and m_fir_tlast;
				-- Places a LUT on the CE port, can be a slow path
				reverse_addr_enable <= s_fft_start or s_fft_tvalid;

				cntr_load_value <= (others => '1');
				i_reverse_addr: reverse_addr
				port map (
												 clk           => aclk,
												 ce            => reverse_addr_enable,
												 load          => s_fft_start,
												 l             => cntr_load_value, --"1111",
																													 --    q(ADDR_SIZE-2 downto 0) => s_fft_read_addr,
																													 --    q(ADDR_SIZE-1)          => s_fft_tvalid
												 q(5-2 downto 0) => s_fft_read_addr,
												 q(5-1)          => s_fft_tvalid
								 );

				i_fft_tvalid_align: process(aclk)
				begin
								if (rising_edge(aclk)) then
												s_fft_tvalid_align <= s_fft_tvalid;
								end if;
				end process;

				i_fft: rx_fft
				port map (
												 aclk => aclk,
												 aresetn => aresetn,
												 s_axis_config_tdata => "00000000", -- FWD/inV(bit 0) 0 = Inverse FFT
												 s_axis_config_tvalid => s_fft_tready, --'1',
												 s_axis_config_tready => s_fft_tready,

												 s_axis_data_tdata => s_fft_tdata,
												 s_axis_data_tvalid => s_fft_tvalid_align,
												 s_axis_data_tready => open,
												 s_axis_data_tlast => '0', -- Ignore event

												 m_axis_data_tdata => m_fft_tdata,
												 m_axis_data_tvalid => m_fft_tvalid,
												 m_axis_data_tready => m_fft_tready,
												 m_axis_data_tlast => open,

												 event_frame_started => open,
												 event_tlast_unexpected => open,
												 event_tlast_missing => open,
												 event_status_channel_halt => open,
												 event_data_in_channel_halt => open,
												 event_data_out_channel_halt => open
								 );

				s_fifo_tdata(47 downto 0) <= m_fft_tdata;

				--  startup_reset_gen_p: process(aclk)
				--  begin
				--    if (rising_edge(aclk)) then
				--      reset_shreg <= reset_shreg(reset_shreg'left-1 downto 0) & '1';
				--      reset_s     <= reset_shreg(reset_shreg'left);
				--    end if;
				--  end process;


				i_fifo: rx_fifo
				port map (
												 s_aclk        => aclk,
												 s_aresetn     => aresetn, --reset_s, --'1',

												 s_axis_tvalid => m_fft_tvalid,
												 s_axis_tready => m_fft_tready,
												 s_axis_tdata  => s_fifo_tdata,

												 m_axis_tvalid => m_axis_tvalid, 
												 m_axis_tready => m_axis_tready,
												 m_axis_tdata  => m_fifo_tdata
								 );
				m_axis_tdata <= m_fifo_tdata(AXIS_TDATA_WIDTH_O-1 downto 0);

end rtl;

