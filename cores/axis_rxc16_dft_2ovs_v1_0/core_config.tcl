set display_name {16 Channels Rx GDFT-FB}

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

