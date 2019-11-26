library ieee;
use ieee.std_logic_1164.all;

entity mux_2x1 is
				generic (N    : natural := 32);
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
end mux_2x1;

architecture rtl of mux_2x1 is

begin

				ready0_o <= '1' when sel = '0' and ready_i = '1' else '0'; 
				ready1_o <= '1' when sel = '1' and ready_i = '1' else '0';

				process (data0_i, data1_i, sel)
				begin
								case sel is
												when '0' => data_o <= data0_i;
												when '1' => data_o <= data1_i;
												when others => data_o <= data0_i;
								end case;
				end process;

				process(valid0_i, valid1_i, sel)
				begin
								case sel is
												when '0' => valid_o <= valid0_i;
												when '1' => valid_o <= valid1_i;
												when others => valid_o <= valid0_i;
								end case;
				end process;
end rtl;

