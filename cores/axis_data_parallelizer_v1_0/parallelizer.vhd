-------------------------------------------------------------------------------
-- Descripcion:
--  Implementa un modulo para pasar datos de serie a paralelo
--  Recibe datos en serie y los saca
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity parallelizer is
				generic(
											 AXIS_TDATA_WIDTH : natural := 32    
							 );
				port ( 
										 aclk           : in  std_logic;
										 aresetn        : in  std_logic;

				             cntr_o         : out std_logic_vector(3-1 downto 0);   
										 -- Slave side
										 s_axis_tready  : out std_logic;
										 s_axis_tdata   : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
										 s_axis_tvalid  : in std_logic;
										 -- Master side
										 m_axis_tdata   : out std_logic_vector (8*AXIS_TDATA_WIDTH-1 downto 0);
										 m_axis_tready  : in  std_logic;
										 m_axis_tvalid  : out std_logic);
end parallelizer;

architecture rtl of parallelizer is

				signal r0_reg, r0_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r1_reg, r1_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r2_reg, r2_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r3_reg, r3_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r4_reg, r4_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r5_reg, r5_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r6_reg, r6_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r7_reg, r7_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal cntr_reg, cntr_next : std_logic_vector(3-1 downto 0);
				signal valid_reg, valid_next : std_logic;

begin

				process(aclk)
				begin
								if (rising_edge(aclk)) then
												if aresetn = '0' then
																r0_reg <= (others => '0');
																r1_reg <= (others => '0');
																r2_reg <= (others => '0');
																r3_reg <= (others => '0');
																r4_reg <= (others => '0');
																r5_reg <= (others => '0');
																r6_reg <= (others => '0');
																r7_reg <= (others => '0');
																cntr_reg <= (others => '0');
																valid_reg       <= '0';
												else
																r0_reg <= r0_next;
																r1_reg <= r1_next;
																r2_reg <= r2_next;
																r3_reg <= r3_next;
																r4_reg <= r4_next;
																r5_reg <= r5_next;
																r6_reg <= r6_next;
																r7_reg <= r7_next;
																cntr_reg <= cntr_next;
																valid_reg       <= valid_next;
												end if;
								end if;
				end process;
				--next state logic
				r0_next <= s_axis_tdata when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r0_reg;
				r1_next <= r0_reg       when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r1_reg;
				r2_next <= r1_reg       when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r2_reg;
				r3_next <= r2_reg       when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r3_reg;
				r4_next <= r3_reg       when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r4_reg;
				r5_next <= r4_reg       when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r5_reg;
				r6_next <= r5_reg       when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r6_reg;
				r7_next <= r6_reg       when (s_axis_tvalid = '1') and (m_axis_tready = '1') else r7_reg;

				cntr_next <= std_logic_vector(unsigned(cntr_reg) +1) when (s_axis_tvalid
										 = '1') and (m_axis_tready = '1') else
										 --(others => '0') when (unsigned(cntr_reg) = 7) else
										 cntr_reg;

				valid_next <= '1' when (unsigned(cntr_reg) = 7) else '0'; 

				cntr_o <= cntr_reg;

				s_axis_tready <= '1';

				--output
				m_axis_tvalid <= valid_reg;
				m_axis_tdata  <= r0_reg & r1_reg & r2_reg & r3_reg & r4_reg & r5_reg &
												 r6_reg & r7_reg;

end rtl;
