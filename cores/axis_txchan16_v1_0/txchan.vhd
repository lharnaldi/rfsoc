-------------------------------------------------------------------------------
-- Descripcion:
--  Implementa un channelizer polifase transmisor de N-canales
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity txchan is
				generic(
											 NCH                : natural := 16; --number of channels
											 AXIS_TDATA_WIDTH_I : natural := 32;
											 --AXIS_TDATA_WIDTH_O : natural := 48    
											 AXIS_TDATA_WIDTH_O : natural := 32    
							 );
				port ( 
										 aclk               : in  std_logic;
										 aresetn            : in  std_logic;
										 s_axis_tdata       : in  std_logic_vector (AXIS_TDATA_WIDTH_I-1 downto 0);
										 s_axis_tvalid      : in  std_logic;
										 s_axis_tready      : out std_logic;

										 --pragma translate off
										 --debug_fft_tvalid   : out std_logic;
										 --debug_fft_tready   : out std_logic;
										 --debug_fft_real     : out std_logic_vector (19 downto 0);
										 --debug_fft_imag     : out std_logic_vector (19 downto 0);
										 --pragma translate on

										 m_axis_tdata       : out  std_logic_vector (AXIS_TDATA_WIDTH_O-1 downto 0);
										 m_axis_tvalid      : out  std_logic);
end txchan;

architecture rtl of txchan is

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

				-- IFFT block
				component tx_fft
								port (
														 aclk                 : in std_logic;
														 aresetn              : in std_logic;
														 s_axis_config_tdata  : in std_logic_vector(7 downto 0);
														 s_axis_config_tvalid : in std_logic;
														 s_axis_config_tready : out std_logic;
														 s_axis_data_tdata    : in std_logic_vector(31 downto 0);
														 s_axis_data_tvalid   : in std_logic;
														 s_axis_data_tready   : out std_logic;
														 s_axis_data_tlast    : in std_logic;
														 m_axis_data_tdata    : out std_logic_vector(47 downto 0);
														 m_axis_data_tvalid   : out std_logic;
														 m_axis_data_tready   : in std_logic;
														 m_axis_data_tlast    : out std_logic;
														 event_frame_started  : out std_logic;
														 event_tlast_unexpected : out std_logic;
														 event_tlast_missing    : out std_logic;
														 event_status_channel_halt  : out std_logic;
														 event_data_in_channel_halt : out std_logic;
														 event_data_out_channel_halt: out std_logic
										 );
				end component;

				-- FIFO to buffer block output of the FFT before the sample based input of the FIR
				component tx_fifo
								port (
														 s_aclk        : in std_logic;
														 s_aresetn     : in std_logic;
														 s_axis_tvalid : in std_logic;
														 s_axis_tready : out std_logic;
														 s_axis_tdata  : in std_logic_vector(63 downto 0);
														 m_axis_tvalid : out std_logic;
														 m_axis_tready : in std_logic;
														 m_axis_tdata  : out std_logic_vector(63 downto 0)
										 );
				end component;

				-- FIR block
				component tx_fir
								port (
														 aclk                 : in std_logic;
														 aresetn              : in std_logic;
														 s_axis_data_tvalid   : in std_logic;
														 s_axis_data_tready   : out std_logic;
														 s_axis_data_tdata    : in std_logic_vector(47 downto 0);
														 s_axis_config_tvalid : in std_logic;
														 s_axis_config_tready : out std_logic;
														 s_axis_config_tlast  : in std_logic;
														 s_axis_config_tdata  : in std_logic_vector(7 downto 0);
														 m_axis_data_tvalid   : out std_logic;
														 m_axis_data_tdata    : out std_logic_vector(47 downto 0);
														 event_s_config_tlast_missing    : out std_logic;
														 event_s_config_tlast_unexpected : out std_logic
										 );
				end component;

				signal s_fifo_tdata,
				m_fifo_tdata              : std_logic_vector(63 downto 0):=(others=>'0');
				signal s_fir_tdata,
				m_fft_tdata,
				m_fir_tdata               : std_logic_vector(47 downto 0):=(others=>'0');
				signal s_fir_config_tdata : std_logic_vector(7 downto 0):=(others=>'0');
				signal m_fft_tvalid, 
				m_fft_tready, 
				m_fifo_tvalid,
				m_fifo_tready,
				s_fir_config_tready,
				s_fir_config_tvalid,
				fir_config_complete       : std_logic := '0';
--				signal reset_shreg        : std_logic_vector(3 downto 0) := (others => '0');
--				signal reset_s            : std_logic := '0';

begin

				i_fft : tx_fft
				port map (
												 aclk => aclk,
												 aresetn => aresetn,

												 s_axis_config_tdata => "00000000", -- FWD/INV(bit 0) 0 = Inverse FFT
												 s_axis_config_tvalid => '1',
												 s_axis_config_tready => open,

												 s_axis_data_tdata  => s_axis_tdata,
												 s_axis_data_tvalid => s_axis_tvalid,
												 s_axis_data_tready => s_axis_tready,
												 s_axis_data_tlast  => '0', -- ignore event

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

				s_fifo_tdata(17 downto 0)  <= m_fft_tdata(19 downto 2);
				s_fifo_tdata(35 downto 18) <= m_fft_tdata(43 downto 26);

				-- Connect debug ports
				--pragma translate off
				--debug_fft_tvalid <= m_fft_tvalid;
				--debug_fft_tready <= m_fft_tready;
				--debug_fft_real   <= m_fft_tdata(19 downto 0);
				--debug_fft_imag   <= m_fft_tdata(43 downto 24);
				--pragma translate on

				-- The FIFO is used to buffer the data between the FFT and FIR
				--  The FFT will produce a burst of data where as FIR will consume the
				--  samples at a continuous slower rate. The average of both cores is
				--  the same and the FIFO should never become full.

--				startup_reset_gen_p: process(aclk)
--				begin
--								if (rising_edge(aclk)) then
--												reset_shreg <= reset_shreg(reset_shreg'left-1 downto 0) & '1';
--												reset_s     <= reset_shreg(reset_shreg'left);
--								end if;
--				end process;

				i_fifo : tx_fifo
				port map (
												 s_aclk => aclk,
												 s_aresetn => aresetn, --reset_s, --'1',
												 --s_aresetn => reset_s, --'1',

												 s_axis_tvalid => m_fft_tvalid,
												 s_axis_tready => m_fft_tready, -- Should never fill i.e. this signal should never de-assert
												 s_axis_tdata  => s_fifo_tdata,

												 m_axis_tvalid => m_fifo_tvalid,
												 m_axis_tready => m_fifo_tready,
												 m_axis_tdata =>  m_fifo_tdata
								 );

				-- Startup configuration for the FIR
				-- Selects which coefficient set to use for which interleaved channel
				i_startup_config: process(aclk)
				begin
								if (rising_edge(aclk)) then
												if s_fir_config_tready = '1' then
																if s_fir_config_tvalid = '1' then
																				s_fir_config_tdata <= std_logic_vector(unsigned(s_fir_config_tdata) + 1);
																				if unsigned(s_fir_config_tdata) = NCH-2 then
																								fir_config_complete <= '1';
																				end if;
																end if;
																s_fir_config_tvalid <= not fir_config_complete;
												end if;
								end if;
				end process;

				s_fir_tdata(17 downto 0)  <= m_fifo_tdata(17 downto 0);
				s_fir_tdata(41 downto 24) <= m_fifo_tdata(35 downto 18);

				i_fir : tx_fir
				port map (
												 aclk    => aclk,
												 aresetn => aresetn,

												 s_axis_data_tvalid => m_fifo_tvalid,
												 s_axis_data_tready => m_fifo_tready,
												 s_axis_data_tdata  => s_fir_tdata,

												 s_axis_config_tvalid => s_fir_config_tvalid,
												 s_axis_config_tready => s_fir_config_tready,
												 s_axis_config_tlast  => '0',  -- Ignore event. The lack of a TLAST pulse will generate an event on 
																											 -- event_s_config_tlast_missing but it does not affect core operation
												 s_axis_config_tdata  => s_fir_config_tdata,

												 m_axis_data_tvalid   => m_axis_tvalid,
												 --m_axis_data_tdata    => m_axis_tdata,
												 m_axis_data_tdata    => m_fir_tdata,

												 event_s_config_tlast_missing    => open,
												 event_s_config_tlast_unexpected => open
								 );

--real_out <= m_fir_tdata(18 downto 0); 
--imag_out <= m_fir_tdata(42 downto 24);
  m_axis_tdata(16-1 downto 0) <= m_fir_tdata(18 downto 3); 
  m_axis_tdata(32-1 downto 16) <= m_fir_tdata(42 downto 27);

end rtl;

