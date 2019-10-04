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

# Create xlslice for reset tlast_gen. off=0
cell xilinx.com:ip:xlslice:1.0 rst_2 {
  DIN_WIDTH 160 DIN_FROM 1 DIN_TO 1 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset conv_0 and writer_0. off=0
cell xilinx.com:ip:xlslice:1.0 rst_3 {
  DIN_WIDTH 160 DIN_FROM 2 DIN_TO 2 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the # of samples to get. off=1
cell xilinx.com:ip:xlslice:1.0 nsamples {
  DIN_WIDTH 160 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
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

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc:1.0 adc_0 {} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn rst_1/Dout
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

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_1 {
  TDATA_NUM_BYTES 4
} {
  s_axis_aclk ps_0/FCLK_CLK0
  s_axis_aresetn rst_1/Dout
  m_axis_aclk pll_0/clk_out1 
  m_axis_aresetn const_0/dout
	S_AXIS gen_tonos_0/M_AXIS
}

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

# Create rxchan16 module
cell labdpr:user:rxchan16:1.0 rxchan16_0 {
} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_1/Dout
	S_AXIS fifo_0/M_AXIS  
}

# Create FIR filter
cell xilinx.com:ip:fir_compiler:7.2 rx_fir {
  Has_ARESETn                  true
  Reset_Data_Vector            false
  ratespecification            Input_Sample_Period
  sampleperiod                 73
  coefficientsource            COE_File 
  coefficient_file [file join $proj_dir coefficients rxchan16.coe]
  coefficient_sets             16
  coefficient_width            25
  coefficient_fractional_bits  27
  data_width                   16
  data_fractional_bits         15
  filter_type                  Single_Rate
  number_channels              16
  number_paths                 2
  output_rounding_mode         Convergent_Rounding_to_Even
  output_width                 19
  s_data_has_fifo              false
  s_config_method              By_Channel
  s_config_sync_mode           On_Vector
  data_has_tlast               Vector_Framing
  m_data_has_tuser             Chan_ID_Field
} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_1/Dout
  S_AXIS_DATA rxchan16_0/FIR_M_AXIS_DATA
  S_AXIS_CONFIG rxchan16_0/FIR_M_AXIS_CONFIG
  M_AXIS_DATA rxchan16_0/FIR_S_AXIS_DATA
	event_s_data_tlast_missing rxchan16_0/event_tl_missing_fir
	event_s_data_tlast_unexpected rxchan16_0/event_tl_unexpected_fir
	event_s_config_tlast_missing rxchan16_0/event_cfg_tl_missing_fir
	event_s_config_tlast_unexpected rxchan16_0/event_cfg_tl_unexpected_fir
}

# Create FFT procesor
cell xilinx.com:ip:xfft:9.0 rx_fft {
  aresetn                 true
  implementation_options  radix_2_lite_burst_io
  output_ordering         natural_order
  butterfly_type          use_xtremedsp_slices
  transform_length        16
  input_width             17
  phase_factor_width      17
  rounding_modes          convergent_rounding
  scaling_options         unscaled
  throttle_scheme         nonrealtime
} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_1/Dout
  S_AXIS_DATA rxchan16_0/IFFT_M_AXIS_DATA
  S_AXIS_CONFIG rxchan16_0/IFFT_M_AXIS_CONFIG
  M_AXIS_DATA rxchan16_0/IFFT_S_AXIS_DATA
	event_frame_started rxchan16_0/event_frame_started_ifft
	event_tlast_unexpected rxchan16_0/event_tl_unexpected_ifft
	event_tlast_missing rxchan16_0/event_tl_missing_ifft
	event_status_channel_halt rxchan16_0/event_status_channel_halt_ifft
	event_data_in_channel_halt rxchan16_0/event_data_in_channel_halt_ifft
	event_data_out_channel_halt rxchan16_0/event_data_out_channel_halt_ifft
}

# Create binary counter
cell xilinx.com:ip:c_counter_binary:12.0 reverse_addr {
  Output_Width      5
  Restrict_Count    true
  Final_Count_Value F
  Count_Mode        DOWN
  CE                true
  Load              true
	} {
	clk ps_0/FCLK_CLK0
	CE rxchan16_0/cntr_ce
	LOAD rxchan16_0/cntr_load
	L rxchan16_0/cntr_l
	Q rxchan16_0/cntr_q
}

# Create memory 
cell xilinx.com:ip:dist_mem_gen:8.0 rx_mem {
  depth           32
	data_width      34
	memory_type     simple_dual_port_ram
	output_options  registered
} {
	clk ps_0/FCLK_CLK0
	qdpo_clk ps_0/FCLK_CLK0
	a rxchan16_0/mem_a
	d rxchan16_0/mem_d
	dpra rxchan16_0/mem_dpra
	we rxchan16_0/mem_we
	qdpo rxchan16_0/mem_qdpo
}

# Create FIFO generator
cell xilinx.com:ip:fifo_generator:13.1 rx_fifo {
  Interface_Type            AXI_STREAM
  FIFO_Implementation_axis  Common_Clock_Distributed_RAM
  Input_Depth_axis          32
  Tdata_Num_Bytes           8
  Tuser_Width               0
} {
  s_aclk ps_0/FCLK_CLK0
  s_aresetn rst_1/Dout
  S_AXIS rxchan16_0/FIFO_M_AXIS
  M_AXIS rxchan16_0/FIFO_S_AXIS
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_1 {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create xlconstant
#cell xilinx.com:ip:xlconstant:1.1 const_2 {
#  CONST_WIDTH 16
#  CONST_VAL 1
#}

# Create the tlast generator
cell labdpr:user:axis_tlast_gen:1.0 tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 32
} {
  S_AXIS rxchan16_0/M_AXIS
  pkt_length nsamples/Dout
  aclk ps_0/FCLK_CLK0
  aresetn rst_2/Dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS tlast_gen_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn rst_3/Dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer:1.0 writer_0 {
  ADDR_WIDTH 20
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk ps_0/FCLK_CLK0
  aresetn rst_3/Dout
}

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]

# Create axi_sts_register
cell labdpr:user:axi_sts_register:1.0 sts_0 {
  STS_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data writer_0/sts_data
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

group_bd_cells Tone_generator [get_bd_cells coef_mem_r] [get_bd_cells coef_mem_i] [get_bd_cells gen_tonos_0]
group_bd_cells Channelizer16 [get_bd_cells rx_mem] [get_bd_cells reverse_addr] [get_bd_cells rx_fifo] [get_bd_cells rx_fir] [get_bd_cells rx_fft] [get_bd_cells rxchan16_0]

