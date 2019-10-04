source projects/base_system/block_design.tcl

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register:1.0 cfg_0 {
  CFG_DATA_WIDTH 160
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

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
#cell xilinx.com:ip:xlslice:1.0 K_p {
#  DIN_WIDTH 160 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
#} {
#  Din cfg_0/cfg_data
#}
#
## Create xlslice for set the loop filter k_i constant. off=2
#cell xilinx.com:ip:xlslice:1.0 K_i {
#  DIN_WIDTH 160 DIN_FROM 95 DIN_TO 64 DOUT_WIDTH 32
#} {
#  Din cfg_0/cfg_data
#}
#
## Create xlslice for set the low pass filter X constant. off=3
#cell xilinx.com:ip:xlslice:1.0 X_value {
#  DIN_WIDTH 160 DIN_FROM 127 DIN_TO 96 DOUT_WIDTH 32
#} {
#  Din cfg_0/cfg_data
#}
#
## Create xlslice for set the output frequency for the generator. off=4
#cell xilinx.com:ip:xlslice:1.0 Freq_value {
#  DIN_WIDTH 160 DIN_FROM 159 DIN_TO 128 DOUT_WIDTH 32
#} {
#  Din cfg_0/cfg_data
#}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create xlconstant
#cell xilinx.com:ip:xlconstant:1.1 const_1

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_1 {
  TDATA_NUM_BYTES 4
} {
  s_axis_aclk ps_0/FCLK_CLK0
  s_axis_aresetn rst_1/Dout
  m_axis_aclk pll_0/clk_out1 
  m_axis_aresetn const_0/dout
}

set proj_dir [file normalize "[pwd]"]

# Create data memory
cell labdpr:user:gen_tonos:1.0 gen_tonos_0 {
} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_1/Dout
}

# Create distributed memory generator
cell xilinx.com:ip:dist_mem_gen:8.0 coef_mem_r {
  depth 16384
  data_width 16
  memory_type rom
  coefficient_file [file join $proj_dir coefficients tx_source_real_cosine_16.coe]
} {
	a gen_tonos_0/a_r
	spo gen_tonos_0/spo_r
}

# Create distributed memory generator
cell xilinx.com:ip:dist_mem_gen:8.0 coef_mem_i {
  depth 16384
  data_width 16
  memory_type rom
  coefficient_file [file join $proj_dir coefficients tx_source_imag_cosine_16.coe]
} {
	a gen_tonos_0/a_i
	spo gen_tonos_0/spo_i
}

# Create txchan16 module
cell labdpr:user:txchan16:1.0 txchan16_0 {
} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_1/Dout
	S_AXIS gen_tonos_0/M_AXIS  
  M_AXIS fifo_1/S_AXIS  
}

# Create FIR filter
cell xilinx.com:ip:fir_compiler:7.2 tx_fir {
  Has_ARESETn                  true
  Reset_Data_Vector            false
  ratespecification            Input_Sample_Period
  sampleperiod                 73
  coefficientsource            COE_File 
  coefficient_file [file join $proj_dir coefficients txchan16.coe]
  coefficient_sets             16
  coefficient_width            25
  coefficient_fractional_bits  27
  data_width                   18
  data_fractional_bits         17
  filter_type                  Single_Rate
  number_channels              16
  number_paths                 2
  output_rounding_mode         Convergent_Rounding_to_Even
  output_width                 19
  s_data_has_fifo              false
  s_config_method              By_Channel
  s_config_sync_mode           On_Vector
} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_1/Dout
  S_AXIS_DATA txchan16_0/FIR_M_AXIS_DATA
  S_AXIS_CONFIG txchan16_0/FIR_M_AXIS_CONFIG
  M_AXIS_DATA txchan16_0/FIR_S_AXIS_DATA
	event_s_config_tlast_missing txchan16_0/fir_event_config_tl_missing
	event_s_config_tlast_unexpected txchan16_0/fir_event_config_tl_unexpected
}

# Create FFT procesor
cell xilinx.com:ip:xfft:9.0 tx_fft {
  aresetn                 true
  implementation_options  radix_2_lite_burst_io
  output_ordering         natural_order
  butterfly_type          use_xtremedsp_slices
  transform_length        16
  input_width             16
  phase_factor_width      17
  rounding_modes          convergent_rounding
  scaling_options         unscaled
  throttle_scheme         nonrealtime
} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_1/Dout
  S_AXIS_DATA txchan16_0/IFFT_M_AXIS_DATA
  S_AXIS_CONFIG txchan16_0/IFFT_M_AXIS_CONFIG
  M_AXIS_DATA txchan16_0/IFFT_S_AXIS_DATA
	event_frame_started txchan16_0/event_frame_started_ifft
	event_tlast_unexpected txchan16_0/event_tl_unexpected_ifft
	event_tlast_missing txchan16_0/event_tl_missing_ifft
	event_status_channel_halt txchan16_0/event_status_channel_halt_ifft
	event_data_in_channel_halt txchan16_0/event_data_in_channel_halt_ifft
	event_data_out_channel_halt txchan16_0/event_data_out_channel_halt_ifft
}

# Create FIFO generator
cell xilinx.com:ip:fifo_generator:13.1 tx_fifo {
  Interface_Type            AXI_STREAM
  FIFO_Implementation_axis  Common_Clock_Distributed_RAM
  Input_Depth_axis          32
  Tdata_Num_Bytes           8
  Tuser_Width               0
} {
  s_aclk ps_0/FCLK_CLK0
  s_aresetn rst_1/Dout
  S_AXIS txchan16_0/FIFO_M_AXIS
  M_AXIS txchan16_0/FIFO_S_AXIS
}

group_bd_cells Tone_generator [get_bd_cells coef_mem_r] [get_bd_cells coef_mem_i] [get_bd_cells gen_tonos_0]
group_bd_cells Channelizer16 [get_bd_cells tx_fifo] [get_bd_cells tx_fir] [get_bd_cells tx_fft] [get_bd_cells txchan16_0]

# Create signal generator
#cell labdpr:user:axis_signal_gen:1.0 sg_0 {
#} {
# aclk pll_0/clk_out1 
# aresetn const_0/Dout 
# S_AXIS fifo_1/M_AXIS  
#}

# Create axis_rp_dac
cell labdpr:user:axis_rp_dac:1.0 dac_0 {} {
  aclk pll_0/clk_out1
  ddr_clk pll_0/clk_out2
  locked pll_0/locked
  S_AXIS fifo_1/M_AXIS
  dac_clk dac_clk_o
  dac_rst dac_rst_o
  dac_sel dac_sel_o
  dac_wrt dac_wrt_o
  dac_dat dac_dat_o
}

#assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
