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

										 -- IFFT interface
										 ifft_m_axis_config_tdata  : out std_logic_vector(7 downto 0);
										 ifft_m_axis_config_tvalid : out std_logic;
										 ifft_m_axis_config_tready : in std_logic;
										 ifft_m_axis_data_tdata    : out std_logic_vector(31 downto 0);
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
										 event_status_channel_halt_ifft  : in std_logic;
										 event_data_in_channel_halt_ifft : in std_logic;
										 event_data_out_channel_halt_ifft: in std_logic;
										 --FIFO interface
										 --fifo_s_aclk               : out std_logic;
										 --fifo_s_aresetn            : out std_logic;
										 fifo_m_axis_tvalid        : out std_logic;
										 fifo_m_axis_tready        : in std_logic;
										 fifo_m_axis_tdata         : out std_logic_vector(63 downto 0);
										 fifo_s_axis_tvalid        : in std_logic;
										 fifo_s_axis_tready        : out std_logic;
										 fifo_s_axis_tdata         : in std_logic_vector(63 downto 0);
										 -- FIR interface
										 --fir_aclk                  : out std_logic;
										 --fir_aresetn               : out std_logic;
										 fir_m_axis_data_tvalid    : out std_logic;
										 fir_m_axis_data_tready    : in std_logic;
										 fir_m_axis_data_tdata     : out std_logic_vector(47 downto 0);
										 fir_m_axis_config_tvalid  : out std_logic;
										 fir_m_axis_config_tready  : in std_logic;
										 fir_m_axis_config_tlast   : out std_logic;
										 fir_m_axis_config_tdata   : out std_logic_vector(7 downto 0);
										 fir_s_axis_data_tvalid    : in std_logic;
										 fir_s_axis_data_tdata     : in std_logic_vector(47 downto 0);
										 fir_event_config_tl_missing    : in std_logic;
										 fir_event_config_tl_unexpected : in std_logic;

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

				signal s_fifo_tdata,
				m_fifo_tdata              : std_logic_vector(63 downto 0):=(others=>'0');
				signal s_fir_tdata,
				m_fft_tdata,
				m_fir_tdata               : std_logic_vector(47 downto 0):=(others=>'0');
				signal m_fir_config_tdata : std_logic_vector(7 downto 0):=(others=>'0');
				signal m_fft_tvalid, 
				m_fft_tready, 
				m_fifo_tvalid,
				m_fifo_tready,
				m_fir_config_tready,
				m_fir_config_tvalid,
				fir_config_complete       : std_logic := '0';
				signal ifft_m_axis_config_tready_i : std_logic;
				signal ifft_s_axis_data_tlast_i    : std_logic;
				signal event_frame_started_ifft_i  : std_logic;
        signal event_tl_unexpected_ifft_i : std_logic;
        signal event_tl_missing_ifft_i    : std_logic;
        signal event_status_channel_halt_ifft_i   : std_logic;
        signal event_data_in_channel_halt_ifft_i  : std_logic;
        signal event_data_out_channel_halt_ifft_i : std_logic;
				signal fir_event_config_tl_missing_i : std_logic;
				signal fir_event_config_tl_unexpected_i : std_logic;

begin

				--IFFT
				ifft_m_axis_config_tdata  <= "00000000"; 
				ifft_m_axis_config_tvalid	<= '1';
				ifft_m_axis_config_tready_i <= ifft_m_axis_config_tready;

				ifft_m_axis_data_tdata  <= s_axis_tdata;
				ifft_m_axis_data_tvalid<= s_axis_tvalid;
				s_axis_tready <= ifft_m_axis_data_tready;
				ifft_m_axis_data_tlast  <= '0'; 

				m_fft_tdata <= ifft_s_axis_data_tdata;
				m_fft_tvalid <= ifft_s_axis_data_tvalid;
				ifft_s_axis_data_tready <= m_fft_tready;
				ifft_s_axis_data_tlast_i <= ifft_s_axis_data_tlast;

				event_frame_started_ifft_i      <= event_frame_started_ifft;
				event_tl_unexpected_ifft_i      <= event_tl_unexpected_ifft;
				event_tl_missing_ifft_i         <= event_tl_missing_ifft;
				event_status_channel_halt_ifft_i   <= event_status_channel_halt_ifft;
				event_data_in_channel_halt_ifft_i  <= event_data_in_channel_halt_ifft;
				event_data_out_channel_halt_ifft_i <= event_data_out_channel_halt_ifft;

				s_fifo_tdata(17 downto 0)  <= m_fft_tdata(19 downto 2);
				s_fifo_tdata(35 downto 18) <= m_fft_tdata(43 downto 26);

				--FIFO
				fifo_m_axis_tvalid <= m_fft_tvalid;
				m_fft_tready <= fifo_m_axis_tready; 
				fifo_m_axis_tdata  <= s_fifo_tdata;

				m_fifo_tvalid <= fifo_s_axis_tvalid;
				fifo_s_axis_tready <= m_fifo_tready;
				m_fifo_tdata <= fifo_s_axis_tdata;

-- Startup configuration for the FIR
-- Selects which coefficient set to use for which interleaved channel
				i_startup_config: process(aclk)
				begin
								if (rising_edge(aclk)) then
												if m_fir_config_tready = '1' then
																if m_fir_config_tvalid = '1' then
																				m_fir_config_tdata <= std_logic_vector(unsigned(m_fir_config_tdata) + 1);
																				if unsigned(m_fir_config_tdata) = NCH-2 then
																								fir_config_complete <= '1';
																				end if;
																end if;
																m_fir_config_tvalid <= not fir_config_complete;
												end if;
								end if;
				end process;

				s_fir_tdata(17 downto 0)  <= m_fifo_tdata(17 downto 0);
				s_fir_tdata(41 downto 24) <= m_fifo_tdata(35 downto 18);

				--FIR
				fir_m_axis_data_tvalid <= m_fifo_tvalid;
				m_fifo_tready <= fir_m_axis_data_tready;
				fir_m_axis_data_tdata  <= s_fir_tdata;

				fir_m_axis_config_tvalid <= m_fir_config_tvalid;
				m_fir_config_tready <= fir_m_axis_config_tready;
				fir_m_axis_config_tlast  <= '0';
				fir_m_axis_config_tdata  <= m_fir_config_tdata;

				m_axis_tvalid <= fir_s_axis_data_tvalid;
				m_fir_tdata   <= fir_s_axis_data_tdata;

				fir_event_config_tl_missing_i    <= fir_event_config_tl_missing;
				fir_event_config_tl_unexpected_i <= fir_event_config_tl_unexpected;

				--real_out <= m_fir_tdata(18 downto 0); 
				--imag_out <= m_fir_tdata(42 downto 24);
				m_axis_tdata(16-1 downto 0) <= m_fir_tdata(18 downto 3); 
				m_axis_tdata(32-1 downto 16) <= m_fir_tdata(42 downto 27);

end rtl;

