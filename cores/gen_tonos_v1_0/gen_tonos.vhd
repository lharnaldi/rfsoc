-------------------------------------------------------------------------------
-- Descripcion:
--  Implementa un wrapper para dos memorias que tienen los datos de entrada para
--  el txchannelizer. Los datos consisten en la parte real y la parte imaginaria
--  de los tonos generados
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gen_tonos is
				generic(
											 AXIS_TDATA_WIDTH : natural := 32    
							 );
				port ( 
										 aclk           : in  std_logic;
										 aresetn        : in  std_logic;
										 a_r     				: out std_logic_vector(14-1 downto 0);
										 spo_r  				: in  std_logic_vector(16-1 downto 0);
										 a_i     				: out std_logic_vector(14-1 downto 0);
										 spo_i  				: in  std_logic_vector(16-1 downto 0);
										 m_axis_tdata   : out std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0);
										 m_axis_tready  : in  std_logic;
										 m_axis_tvalid  : out std_logic);
end gen_tonos;

architecture rtl of gen_tonos is

				signal mem_rd_addr_reg, mem_rd_addr_next : std_logic_vector(14-1 downto 0);
				signal mem_r_dout, mem_i_dout            : std_logic_vector(16-1 downto 0);
				signal valid_reg, valid_next             : std_logic;

begin

				i_mem_rd: process(aclk)
        begin
                if (rising_edge(aclk)) then
												if aresetn = '0' then
																mem_rd_addr_reg <= (others => '0');
																valid_reg       <= '0';
												else
																mem_rd_addr_reg <= mem_rd_addr_next;
																valid_reg       <= valid_next;
												end if;
                end if;
        end process;
				--next state logic
				mem_rd_addr_next <= std_logic_vector(unsigned(mem_rd_addr_reg) + 1) when ((m_axis_tready = '1') and (valid_reg = '1')) else
														mem_rd_addr_reg;

				valid_next <= '1'; 

				a_r    <= std_logic_vector(unsigned(mem_rd_addr_reg)-1);
				mem_r_dout <= spo_r;

				a_i    <= std_logic_vector(unsigned(mem_rd_addr_reg)-1);
				mem_i_dout <= spo_i;

				--output
				m_axis_tvalid <= valid_reg;
				m_axis_tdata  <= mem_i_dout & mem_r_dout;

end rtl;
