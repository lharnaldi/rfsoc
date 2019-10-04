# Constraint to avoid cross-checking between clock domains.
set_clock_group -name clk_pl0_to_RFADC0_CLK -asynchronous \
    -group [get_clocks clk_pl_0] \
    -group [get_clocks RFADC0_CLK]
    
set_clock_group -name clk_pl0_to_RFDAC0_CLK -asynchronous \
    -group [get_clocks clk_pl_0] \
    -group [get_clocks RFDAC0_CLK]
    
set_clock_group -name clk_pl0_to_pllADC -asynchronous \
    -group [get_clocks clk_pl_0] \
    -group [get_clocks *clk_wiz*]     
