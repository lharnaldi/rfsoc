set display_name {16 Channels Tx PFB wrapper}

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

set ifft_bus [ipx::get_bus_interfaces -of_objects $core ifft_m_axis_data]
set_property NAME IFFT_M_AXIS_DATA $ifft_bus
set_property INTERFACE_MODE master $ifft_bus

set ifft_bus [ipx::get_bus_interfaces -of_objects $core ifft_s_axis_data]
set_property NAME IFFT_S_AXIS_DATA $ifft_bus
set_property INTERFACE_MODE slave $ifft_bus

set ifft_bus [ipx::get_bus_interfaces -of_objects $core ifft_m_axis_config]
set_property NAME IFFT_M_AXIS_CONFIG $ifft_bus
set_property INTERFACE_MODE master $ifft_bus

set fifo_bus [ipx::get_bus_interfaces -of_objects $core fifo_m_axis]
set_property NAME FIFO_M_AXIS $fifo_bus
set_property INTERFACE_MODE master $fifo_bus

set fifo_bus [ipx::get_bus_interfaces -of_objects $core fifo_s_axis]
set_property NAME FIFO_S_AXIS $fifo_bus
set_property INTERFACE_MODE slave $fifo_bus

set fir_bus [ipx::get_bus_interfaces -of_objects $core fir_m_axis_data]
set_property NAME FIR_M_AXIS_DATA $fir_bus
set_property INTERFACE_MODE master $fir_bus

set fir_bus [ipx::get_bus_interfaces -of_objects $core fir_s_axis_data]
set_property NAME FIR_S_AXIS_DATA $fir_bus
set_property INTERFACE_MODE slave $fir_bus

set fir_bus [ipx::get_bus_interfaces -of_objects $core fir_m_axis_config]
set_property NAME FIR_M_AXIS_CONFIG $fir_bus
set_property INTERFACE_MODE master $fir_bus

set bus [ipx::get_bus_interfaces aclk]
set parameter [ipx::get_bus_parameters -of_objects $bus ASSOCIATED_BUSIF]
set_property VALUE M_AXIS:S_AXIS:IFFT_M_AXIS_DATA:IFFT_S_AXIS_DATA:IFFT_M_AXIS_CONFIG:FIFO_M_AXIS:FIFO_S_AXIS:FIR_M_AXIS_DATA:FIR_S_AXIS_DATA:FIR_M_AXIS_CONFIG $parameter

