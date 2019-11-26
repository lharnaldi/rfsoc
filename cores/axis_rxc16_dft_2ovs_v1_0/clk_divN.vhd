library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_divN is
				generic( 
											 N : natural := 8
							 );
				port (
										 aclk    : in std_logic; 
										 aresetn : in std_logic;
										 en      : in std_logic;
										 div_N   : out std_logic
						 );
end clk_divN;

architecture arch of clk_divN is

				signal cnt : integer := 0;
				signal div_temp : std_logic := '0';

begin
				process(aclk) 
				begin
								if rising_edge(aclk) then
												if aresetn = '0' then
																div_temp <= '0';
																cnt      <= 0;
												else
																if en = '1' then
																				if cnt >= N-1 then
																								div_temp <= not(div_temp);
																								cnt <= 0;
																				else
																								div_temp <= div_temp;
																								cnt <= cnt + 1;
																				end if;
																end if;
																div_N <= div_temp;
												end if;
								end if;
				end process;
end arch;
