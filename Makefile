ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
export PATH := $(ROOT_DIR)/scripts/:$(PATH)

XILINX_INSTALL_DIR=/tools
XILINX_VERSION=2019.2
XILINX_VIVADO=$(XILINX_INSTALL_DIR)/Xilinx/Vivado/$(XILINX_VERSION)
VIVADO=$(XILINX_INSTALL_DIR)/Xilinx/Vivado/$(XILINX_VERSION)/bin/vivado
XSCT=$(XILINX_INSTALL_DIR)/Xilinx/Vitis/$(XILINX_VERSION)/bin/xsct
HW_SERVER=$(XILINX_INSTALL_DIR)/Xilinx/Vitis/$(XILINX_VERSION)/bin/hw_server

JTAG_CABLE_NAME="Xilinx TUL 1234-tulA"

IP_NAME=mux_ro_variance
IP_MAJOR_VERSION=1
IP_MINOR_VERSION=0
LIBRARY_NAME=coso_lib
VITIS_APP_NAME=mux_ro_variance_app
HW_SERVER_PID_FILE=hw_server.pid


output/post_synth.dcp: scripts/synth.tcl scripts/create_bd.tcl src/ip/vhdl*/*.vhd $(wildcard src/constraints/*.xdc)
	@ pretty_print " Setup and Synthetisize Design "
	@ mkdir -p $(ROOT_DIR)/output
	cd $(ROOT_DIR)/scripts; $(VIVADO) \
		-mode batch \
		-source synth.tcl \
		-log ../output/synth.log \
		-nojournal \
		-tclargs \
			-ip_name $(IP_NAME) \
			-ip_major_version $(IP_MAJOR_VERSION) \
			-ip_minor_version $(IP_MINOR_VERSION) \
			-library_name $(LIBRARY_NAME) \
		|| { pretty_print " Synthetization failed "; exit 1; };


synth:  output/post_synth.dcp ## synthetisize
	@ sleep 1
	@ pretty_print " Synthetization finished "

post_synth_gui:  output/post_synth.dcp ## synthetisize the design and open the gui
	@ pretty_print " Open Synthetisized Design "
	@ echo -e '\033[0;31mRun write_xdc to write user constraints and add them to src/constraints/\033[0m'
	cd $(ROOT_DIR)/scripts; $(VIVADO) -mode batch -source post_synth_gui.tcl -tclargs


output/post_place.dcp:  scripts/place.tcl output/post_synth.dcp
	@ pretty_print " Place Design "
	cd $(ROOT_DIR)/scripts; $(VIVADO) \
		-mode batch \
		-source place.tcl \
		-log ../output/place.log \
		-nojournal \
		|| { pretty_print " Placement failed "; exit 1; };

place:  output/post_place.dcp ## place the design
	@ sleep 1
	@ pretty_print " Placement finished "

post_place_gui:  output/post_place.dcp ## place the design and open the gui
	@ pretty_print " Open Placed Design "
	cd $(ROOT_DIR)/script; $(VIVADO) -mode batch -source post_place_gui.tcl -tclargs


output/post_route.dcp:  scripts/route.tcl output/post_place.dcp
	@ pretty_print " Route Design "
	cd $(ROOT_DIR)/scripts; $(VIVADO) \
		-mode batch \
		-source route.tcl \
		-log ../output/route.log \
		-nojournal \
		|| { pretty_print " Routing failed "; exit 1; }

route:  output/post_route.dcp ## route the design
	@ pretty_print " Routing finished "

post_route_gui:  output/post_route.dcp ## place the design and open the gui
	@ pretty_print " Open Routed Design "
	cd $(ROOT_DIR)/scripts; $(VIVADO) -mode batch -source post_route_gui.tcl -tclargs


output/design_1_wrapper_$(IP_NAME).xsa:  scripts/write_hw.tcl output/post_route.dcp
	@ pretty_print " Write Hardware "
	rm -rf vitis_workspace; \
	cd $(ROOT_DIR)/scripts; $(VIVADO) \
		-mode batch \
		-source write_hw.tcl \
		-log ../output/write_hw.log \
		-nojournal \
		-tclargs \
			-ip_name $(IP_NAME) \
		|| { pretty_print " Writing hardware failed "; exit 1; };\

write_hw:  output/design_1_wrapper_$(IP_NAME).xsa ## write the xsa hw_file
	@ pretty_print " Writing hardware finished "


vitis_workspace/$(VITIS_APP_NAME)/_ide/bitstream/design_1_wrapper_$(IP_NAME).bit: scripts/setup_platform.tcl output/design_1_wrapper_$(IP_NAME).xsa
	@ pretty_print " Setup Vitis Platform "
	cd $(ROOT_DIR)/scripts; $(XSCT) setup_platform.tcl \
		-app_name $(VITIS_APP_NAME) \
		-hw_file ../output/design_1_wrapper_$(IP_NAME).xsa \
		|| { pretty_print " Setup platform failed "; exit 1; };\

setup_platform: vitis_workspace/$(VITIS_APP_NAME)/_ide/bitstream/design_1_wrapper_$(IP_NAME).bit ## create the vitis platform and app
	pretty_print " Setup platform finished "



vitis_workspace/$(VITIS_APP_NAME)/Debug/$(VITIS_APP_NAME).elf: scripts/build.tcl vitis_workspace/$(VITIS_APP_NAME)/_ide/bitstream/design_1_wrapper_$(IP_NAME).bit src/c/*.c src/c/*.h
	@ pretty_print " Build Software "
	cd $(ROOT_DIR)/scripts; bash build.sh \
		--xsct $(XSCT) \
		--app_name $(VITIS_APP_NAME) \
		--hw_file ../output/design_1_wrapper_$(IP_NAME).xsa \
		--elf_file ../vitis_workspace/$(VITIS_APP_NAME)/Debug/$(VITIS_APP_NAME).elf \
		|| { pretty_print " Vitis build failed "; exit 1; };

build: vitis_workspace/$(VITIS_APP_NAME)/Debug/$(VITIS_APP_NAME).elf ## build the application software
	pretty_print " Vitis build finished "

launch: scripts/launch.tcl vitis_workspace/$(VITIS_APP_NAME)/Debug/$(VITIS_APP_NAME).elf ## launch the application on the hardware
	@ pretty_print " Launch on Hardware "
	start_hw_server $(HW_SERVER) $(HW_SERVER_PID_FILE)
	cd $(ROOT_DIR)/scripts; $(XSCT) launch.tcl \
		-app_name $(VITIS_APP_NAME) \
		-hw_file ../output/design_1_wrapper_$(IP_NAME).xsa \
		-bit_file $(VITIS_APP_NAME)/_ide/bitstream/design_1_wrapper_$(IP_NAME).bit \
		-elf_file $(VITIS_APP_NAME)/Debug/$(VITIS_APP_NAME).elf \
		-jtag_cable_name $(JTAG_CABLE_NAME) \
		|| { pretty_print " Launch failed "; exit 1; }


test:	## run simulation tests
	@  pretty_print " Running Tests "
	@ mkdir -p $(ROOT_DIR)/output
	@ mkdir -p $(ROOT_DIR)/sim
	cd $(ROOT_DIR)/sim; $(VIVADO) \
		-mode batch \
		-source ../scripts/test.tcl \
		-notrace \
		-log ../output/test.log \
		-nojournal \
		-tclargs \
			-xilinx_vivado $(XILINX_VIVADO) \
			-library_name $(LIBRARY_NAME) \
		|| { pretty_print " Test failed "; exit 1; }


tb_gui-%: sim/xsim.dir/sim_snapshot_% ## run simulation gui for test %
	@ pretty_print " Running testbench $(subst tb_gui-,,$@) "
	cd $(ROOT_DIR)/sim; $(VIVADO)\
		-mode batch \
		-source ../scripts/test_gui.tcl \
		-notrace \
		-log ../output/test.log \
		-nojournal \
		-tclargs \
			-xilinx_vivado $(XILINX_VIVADO) \
			-library_name $(LIBRARY_NAME) \
			-tb_name $(subst tb_gui-,,$@)


clean: clean_vitis clean_vivado ## remove all autogenerated files


clean_vivado: ## remove vivado autogenerated files
	@  pretty_print " Removing Vivado autogenerated files... "
	rm -rf ./IP
	rm -rf ./scripts/.srcs
	rm -rf ./scripts/.cache
	rm -rf ./scripts/.Xil
	rm -rf ./output/
	rm -rf ./sim/


clean_vitis: ## remove vitis autogenerated files
	@ pretty_print " Removing Vitis autogenerated files... "
	stop_hw_server $(HW_SERVER_PID_FILE)
	rm -f $(HW_SERVER_PID_FILE)
	rm -rf ./vitis_workspace/


help:  # http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
	@grep -P '^[%a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'


.DEFAULT_GOAL := help
.PHONY: help clean clean_vitis synth place route write_hw setup_platform build launch test tb_gui-% tidy
