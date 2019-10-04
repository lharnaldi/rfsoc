# Create gen_tonos
cell xilinx.com:ip:dist_mem_gen:8.0 dist_mem_gen_r {}

# Create gen_tonos
cell xilinx.com:ip:dist_mem_gen:8.0 dist_mem_gen_r {}

# Create gen_tonos
cell labdpr:user:gen_tonos:1.0 gen_tonos_0 {}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

# Create xlslice for reset modules. off=0
cell xilinx.com:ip:xlslice:1.0 rst_1 {
  DIN_WIDTH 160 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the loop filter k_p constant. off=1
cell xilinx.com:ip:xlslice:1.0 K_p {
  DIN_WIDTH 160 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the loop filter k_i constant. off=2
cell xilinx.com:ip:xlslice:1.0 K_i {
  DIN_WIDTH 160 DIN_FROM 95 DIN_TO 64 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the low pass filter X constant. off=3
cell xilinx.com:ip:xlslice:1.0 X_value {
  DIN_WIDTH 160 DIN_FROM 127 DIN_TO 96 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the output frequency for the generator. off=4
cell xilinx.com:ip:xlslice:1.0 Freq_value {
  DIN_WIDTH 160 DIN_FROM 159 DIN_TO 128 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_1

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_1 {
  TDATA_NUM_BYTES 4
} {
  s_axis_tdata Freq_value/Dout
	s_axis_tvalid const_1/dout
  s_axis_aclk ps_0/FCLK_CLK0
  s_axis_aresetn rst_1/Dout
  m_axis_aclk pll_0/clk_out1 
  m_axis_aresetn const_0/dout
}

# Create signal generator
cell labdpr:user:axis_signal_gen:1.0 sg_0 {
} {
 aclk pll_0/clk_out1 
 aresetn const_0/Dout 
 S_AXIS fifo_1/M_AXIS  
}

# Create axis_rp_dac
cell labdpr:user:axis_rp_dac:1.0 dac_0 {} {
  aclk pll_0/clk_out1
  ddr_clk pll_0/clk_out2
  locked pll_0/locked
  S_AXIS sg_0/M_AXIS
  dac_clk dac_clk_o
  dac_rst dac_rst_o
  dac_sel dac_sel_o
  dac_wrt dac_wrt_o
  dac_dat dac_dat_o
}

#assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
