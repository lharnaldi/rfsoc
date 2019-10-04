set display_name {16 Channels Tx PFB}

set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

core_parameter NCH {Number of channels} {Number of channels.}
core_parameter AXIS_TDATA_WIDTH_I {Width of the input data} {Width of the input data bus.}
core_parameter AXIS_TDATA_WIDTH_O {Width of the output data} {Width of the output data bus.}

set bus [ipx::get_bus_interfaces -of_objects $core m_axis]
set_property NAME M_AXIS $bus
set_property INTERFACE_MODE master $bus

set bus [ipx::get_bus_interfaces -of_objects $core s_axis]
set_property NAME S_AXIS $bus
set_property INTERFACE_MODE slave $bus

set bus [ipx::get_bus_interfaces aclk]
set parameter [ipx::get_bus_parameters -of_objects $bus ASSOCIATED_BUSIF]
set_property VALUE M_AXIS:S_AXIS $parameter

set proj_dir [file normalize "[pwd]"]

###############################################################################
# Add/Create Tx path IP cores
create_ip -name fir_compiler -version 7.2 -vendor xilinx.com -library ip -module_name tx_fir
set_property -name CONFIG.Has_ARESETn                  -value {true} -objects [get_ips tx_fir]
set_property -name CONFIG.Reset_Data_Vector            -value {false} -objects [get_ips tx_fir]
set_property -name CONFIG.ratespecification            -value {Input_Sample_Period} -objects [get_ips tx_fir]
set_property -name CONFIG.sampleperiod                 -value {73} -objects [get_ips tx_fir]
set_property -dict [list CONFIG.coefficientsource {COE_File} CONFIG.coefficient_file [file join $proj_dir coefficients txchan16.coe]] -objects [get_ips tx_fir]
set_property -name CONFIG.coefficient_sets             -value {16} -objects [get_ips tx_fir]
set_property -name CONFIG.coefficient_width            -value {25} -objects [get_ips tx_fir]
set_property -name CONFIG.coefficient_fractional_bits  -value {27} -objects [get_ips tx_fir]
set_property -name CONFIG.data_width                   -value {18} -objects [get_ips tx_fir]
set_property -name CONFIG.data_fractional_bits         -value {17} -objects [get_ips tx_fir]
set_property -name CONFIG.filter_type                  -value {Single_Rate} -objects [get_ips tx_fir]
set_property -name CONFIG.number_channels              -value {16} -objects [get_ips tx_fir]
set_property -name CONFIG.number_paths                 -value {2} -objects [get_ips tx_fir]
set_property -name CONFIG.output_rounding_mode         -value {Convergent_Rounding_to_Even} -objects [get_ips tx_fir]
set_property -name CONFIG.output_width                 -value {19} -objects [get_ips tx_fir]
set_property -name CONFIG.s_data_has_fifo              -value {false} -objects [get_ips tx_fir]
set_property -name CONFIG.s_config_method              -value {By_Channel} -objects [get_ips tx_fir]
set_property -name CONFIG.s_config_sync_mode           -value {On_Vector} -objects [get_ips tx_fir]

create_ip -name xfft -version 9.1 -vendor xilinx.com -library ip -module_name tx_fft
set_property -name CONFIG.aresetn                 -value {true} -objects [get_ips tx_fft]
set_property -name CONFIG.implementation_options  -value {radix_2_lite_burst_io} -objects [get_ips tx_fft]
set_property -name CONFIG.output_ordering         -value {natural_order} -objects [get_ips tx_fft]
set_property -name CONFIG.butterfly_type          -value {use_xtremedsp_slices} -objects [get_ips tx_fft]
set_property -name CONFIG.transform_length        -value {16} -objects [get_ips tx_fft]
set_property -name CONFIG.input_width             -value {16} -objects [get_ips tx_fft]
set_property -name CONFIG.phase_factor_width      -value {17} -objects [get_ips tx_fft]
set_property -name CONFIG.rounding_modes          -value {convergent_rounding} -objects [get_ips tx_fft]
set_property -name CONFIG.scaling_options         -value {unscaled} -objects [get_ips tx_fft]
set_property -name CONFIG.throttle_scheme         -value {nonrealtime} -objects [get_ips tx_fft]

create_ip -name fifo_generator -version 13.2 -vendor xilinx.com -library ip -module_name tx_fifo
set_property -name CONFIG.Interface_Type            -value {AXI_STREAM} -objects [get_ips tx_fifo]
set_property -name CONFIG.FIFO_Implementation_axis  -value {Common_Clock_Distributed_RAM} -objects [get_ips tx_fifo]
set_property -name CONFIG.Input_Depth_axis          -value {32} -objects [get_ips tx_fifo]
set_property -name CONFIG.Tdata_Num_Bytes           -value {8} -objects [get_ips tx_fifo]
set_property -name CONFIG.Tuser_Width               -value {0} -objects [get_ips tx_fifo]
