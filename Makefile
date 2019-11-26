# 'make' builds everything
# 'make clean' deletes everything except source files and Makefile
#
# You need to set NAME, PART and PROC for your project.
# NAME is the base name for most of the generated files.

# solves problem with awk while building linux kernel
# solution taken from http://www.googoolia.com/wp/2015/04/21/awk-symbol-lookup-error-awk-undefined-symbol-mpfr_z_sub/
LD_LIBRARY_PATH =

NAME = led_blinker
PART = xczu28dr-ffvg1517-2-e
#PART = xc7z010clg400-1
#PROC = ps7_cortexa9_0

CORES = axi_axis_reader_v1_0 \
				axi_axis_writer_v1_0 \
				axi_cfg_register_v1_0 \
				axis_constant_v1_0 \
				axis_counter_v1_0 \
				axis_data_parallelizer_v1_0 \
				axis_gpio_reader_v1_0 \
				axis_packetizer_v1_0 \
				axis_ram_writer_v1_0 \
				axis_rxchan16_v1_0\
				axis_rxc16_dft_2ovs_v1_0 \
				axis_signal_gen_v1_0 \
				axi_sts_register_v1_0 \
				axis_tlast_gen_v1_0 \
				axis_trigger_v1_0 \
				axis_txchan16_v1_0\
				dna_reader_v1_0 \
				gen_tonos_v1_0 \
				pps_gen_v1_0 \
				rxchan16_v1_0 \
				txchan16_v1_0

VIVADO = vivado -nolog -nojournal -mode batch
#HSI = hsi -nolog -nojournal -mode batch
RM = rm -rf

.PRECIOUS: tmp/cores/% tmp/%.xpr tmp/%.hwdef tmp/%.bit 

all: bit

cores: $(addprefix tmp/cores/, $(CORES))

xpr: tmp/$(NAME).xpr

bit: tmp/$(NAME).bit

tmp/cores/%: cores/%/core_config.tcl cores/%/*.vhd
	mkdir -p $(@D)
	$(VIVADO) -source scripts/core.tcl -tclargs $* $(PART)

tmp/%.xpr: projects/% $(addprefix tmp/cores/, $(CORES))
	mkdir -p $(@D)
	$(VIVADO) -source scripts/project.tcl -tclargs $* $(PART)

tmp/%.hwdef: tmp/%.xpr
	mkdir -p $(@D)
	$(VIVADO) -source scripts/hwdef.tcl -tclargs $*

tmp/%.bit: tmp/%.xpr
	mkdir -p $(@D)
	$(VIVADO) -source scripts/bitstream.tcl -tclargs $*

#tmp/%.fsbl/executable.elf: tmp/%.hwdef
#	mkdir -p $(@D)
#	$(HSI) -source scripts/fsbl.tcl -tclargs $* $(PROC)

clean:
	$(RM) tmp
	$(RM) .Xil usage_statistics_webtalk.html usage_statistics_webtalk.xml
	$(RM) vivado*.jou vivado*.log
	$(RM) webtalk*.jou webtalk*.log
