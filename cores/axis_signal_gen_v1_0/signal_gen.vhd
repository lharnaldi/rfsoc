library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_gen is
				generic (
												ADC_DATA_WIDTH : natural := 14;
												AXIS_TDATA_WIDTH: natural := 32
								);
				port(
										aclk        : in std_logic;		
										aresetn     : in std_logic;	
										--freq_i      : in std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0);				
										sync_o      : out std_logic;	
										--sin_o       : out std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
										--cos_o       : out std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);

										-- Slave side
										s_axis_tready : out std_logic;
										s_axis_tvalid : in std_logic;
										s_axis_tdata  : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

										-- Master side
										m_axis_tready : in std_logic;
										m_axis_tvalid : out std_logic;
										m_axis_tdata  : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)

						);
end signal_gen;

architecture rtl of signal_gen is

				constant PADDING_WIDTH : natural := AXIS_TDATA_WIDTH/2 - ADC_DATA_WIDTH;

				signal phase_acc_reg, phase_acc_next: std_logic_vector (50-1 downto 0);
				signal phase_step                   : std_logic_vector (50-1 downto 0) := (others => '0');
        signal r2_reg, r2_next              : std_logic_vector(50-1 downto 0);
        signal r3_reg, r3_next              : std_logic_vector(50-1 downto 0);
        signal dds_sync                     : std_logic;
        signal r_const_reg, r_const_next    : unsigned(18-1 downto 0);

				signal lut_addr                     : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
				signal sin_s, cos_s                 : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);

				signal freq_reg, freq_next          : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal tvalid                       : std_logic := '0';
				signal sin_reg, sin_next            : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
				signal cos_reg, cos_next            : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
				signal tready                       : std_logic;
begin

				tready <= '1';
				s_axis_tready <= tready;

				process(aclk)
				begin
								if rising_edge(aclk) then
												if aresetn = '0' then
																phase_acc_reg <= (others => '0');
																freq_reg      <= (others => '0');
																r2_reg        <= (others => '0');
																r2_reg        <= (others => '0');
                                r3_reg        <= (others => '0');
																r_const_reg   <= to_unsigned(35184,18);
												else
																phase_acc_reg <= phase_acc_next;
																freq_reg      <= freq_next;
																r2_reg        <= r2_next;
                                r3_reg        <= r3_next;
                                r_const_reg   <= r_const_next;
												end if;
								end if;
				end process;

				--next state
				--freq_next <= freq_i;
				freq_next <= s_axis_tdata when (s_axis_tvalid = '1') and (tready = '1') else freq_reg;

				r_const_next <= to_unsigned(35184,18);

				--fout = fclock * A / (# step per full cycle) * fin *2^6.     # steps is 2^50, f=125MHz => A = 140737.
				--phase_step <= std_logic_vector(to_unsigned(140737,20) * unsigned(freq_i)); 
				phase_step <= std_logic_vector(r_const_reg * unsigned(freq_reg)); --for 2^8

		    r2_next <= phase_step;
        r3_next <= r2_reg;

        phase_acc_next <= std_logic_vector(unsigned(phase_acc_reg) + unsigned(r3_reg));

				--phase_acc_next <= std_logic_vector(unsigned(phase_acc_reg) + unsigned(phase_step)); 

				--output
				--phase_I <= phase_acc_reg(49 downto 40);
				----phase_I <= phase_acc_reg(49 downto 36);
				----phase_Q <= std_logic_vector(unsigned(phase_acc_reg(49 downto 40)) + to_unsigned(255, 10)); --phase of Q is 90deg advanced from I. 256.
				--phase_Q <= std_logic_vector(unsigned(phase_acc_reg(49 downto 36)) + to_unsigned(4095, 10)); --phase of Q is 90deg advanced from I. 256.
				sync_o <= not(phase_acc_reg(50-1));

				lut_addr <= phase_acc_reg(50-1 downto 36);

				LUT: entity work.sincos_lut_14
				port map(
												clk_i   => aclk,
												addr_i  => lut_addr,
												sin     => sin_s,
												cos     => cos_s
								);


				process(aclk)
				begin
								if rising_edge(aclk) then
												if (aresetn = '0') then
																sin_reg <= (others => '0');
																cos_reg <= (others => '0');
												else
																sin_reg <= sin_next;
																cos_reg <= cos_next;
												end if;
								end if;
				end process;

				tvalid <= '1' when (unsigned(freq_reg) /= 0) else '0';

				--next state
				sin_next <= sin_s when (m_axis_tready = '1') and (tvalid = '1') else
										sin_reg;
				cos_next <= cos_s when (m_axis_tready = '1') and (tvalid = '1') else
										cos_reg;

				--output
				m_axis_tvalid <= tvalid;

				--sin_o <= ((PADDING_WIDTH-1) downto 0 => sin_reg(ADC_DATA_WIDTH-1)) & sin_reg;
				--cos_o <= ((PADDING_WIDTH-1) downto 0 => cos_reg(ADC_DATA_WIDTH-1)) & cos_reg;
				--sin_o <= sin_s & "00";
				--cos_o <= cos_s & "00";
				m_axis_tdata <= ((PADDING_WIDTH-1) downto 0 => sin_reg(ADC_DATA_WIDTH-1)) & sin_reg & ((PADDING_WIDTH-1) downto 0 => cos_reg(ADC_DATA_WIDTH-1)) & cos_reg;

end rtl;

