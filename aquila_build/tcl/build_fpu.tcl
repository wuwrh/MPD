#*****************************************************************************************
#  Create the aquial_ap workspace.      Chun-Jen Tsai Sep/03/2025
# ----------------------------------------------------------------------------------------
#  Note that the source files under ./src are not copied into the workspace.
#  Any modifications of the source files from the Vivado GUI will be made directly
#  to the files in the ./src directory.
#*****************************************************************************************

# Set workspace parameters.
set proj_name   "aquila_fpu"
set fpga_model  xc7a100tcsg324-1
set board_model ARTY
set xdc_file    arty.xdc
set mig_file    mig-arty100t.prj

# Create an empty project workspace of an FPGA model.
create_project $proj_name ./$proj_name -part $fpga_model

# Set the source tree root directory.
set source_dir "./src"

# Set project properties
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_MEMORY" -objects $obj

# Start reading source files from the source directory.
read_verilog $source_dir/core_rtl/alu.v
read_verilog $source_dir/core_rtl/aquila_config.vh
read_verilog $source_dir/core_rtl/aquila_top.v
read_verilog $source_dir/core_rtl/atomic_unit.v
read_verilog $source_dir/core_rtl/bcu.v
read_verilog $source_dir/core_rtl/bpu.v
read_verilog $source_dir/core_rtl/clint.v
read_verilog $source_dir/core_rtl/core_top.v
read_verilog $source_dir/core_rtl/csr_file.v
read_verilog $source_dir/core_rtl/dcache.v
read_verilog $source_dir/core_rtl/decode.v
read_verilog $source_dir/core_rtl/distri_ram.v
read_verilog $source_dir/core_rtl/execute.v
read_verilog $source_dir/core_rtl/fetch.v
read_verilog $source_dir/core_rtl/forwarding_unit.v
read_verilog $source_dir/core_rtl/fp_forwarding_unit.v
read_verilog $source_dir/core_rtl/icache.v
read_verilog $source_dir/core_rtl/memory.v
read_verilog $source_dir/core_rtl/muldiv.v
read_verilog $source_dir/core_rtl/pipeline_control.v
read_verilog $source_dir/core_rtl/program_counter.v
read_verilog $source_dir/core_rtl/reg_file.v
read_verilog $source_dir/core_rtl/fp_reg_file.v
read_verilog $source_dir/core_rtl/sram.v
read_verilog $source_dir/core_rtl/sram_dp.v
read_verilog $source_dir/core_rtl/writeback.v
read_verilog $source_dir/soc_rtl/uart.v
read_verilog $source_dir/soc_rtl/core2axi_if.v
read_verilog $source_dir/soc_rtl/cdc_sync.v
read_verilog $source_dir/soc_rtl/mem_arbiter.v

# Read synthesis-only files.
add_files -fileset sources_1 -norecurse $source_dir/soc_rtl/soc_top.v

# Read memory and constraints files.
read_mem $source_dir/mem/uartboot.mem
read_xdc $source_dir/xdc/$xdc_file

# Define the target board parameters for synthesis.
set_property verilog_define [list $board_model ENABLE_FPU] [get_filesets sources_1]

# Set top-level module for synthesis.
set_property top soc_top [get_filesets sources_1]

# Read simulation-only files.
add_files -fileset sim_1 -norecurse $source_dir/soc_rtl/soc_tb.v
add_files -fileset sim_1 -norecurse $source_dir/soc_rtl/memctrl_sim.v

# Define the target board parameters for simulation.
set_property verilog_define [list $board_model ENABLE_FPU] [get_filesets sim_1]

# Set top-level module for simulation.
set_property top soc_tb [get_filesets sim_1]
set_property -name "top_lib" -value "xil_defaultlib" -objects [get_filesets sim_1]

# ===========================================================================================
#  The following commands adds soft-core IP into the workspace.
# ===========================================================================================

# Adding an Asynchronous FIFO Addr IP
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name async_fifo_addr
set_property -dict [list \
    CONFIG.fifo_implementation {independent_clocks_distributed_ram} \
    CONFIG.synchronization_stages {3} \
    CONFIG.input_data_width {32} \
    CONFIG.input_depth {16} \
    CONFIG.reset_pin {false} \
    CONFIG.performance_options {first_word_fall_through} ] [get_ips async_fifo_addr]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/async_fifo_addr/async_fifo_addr.xci]

# Adding an Asynchronous FIFO Data IP
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name async_fifo_data
set_property -dict [list \
    CONFIG.fifo_implementation {independent_clocks_distributed_ram} \
    CONFIG.synchronization_stages {3} \
    CONFIG.input_data_width {128} \
    CONFIG.input_depth {16} \
    CONFIG.reset_pin {false} \
    CONFIG.performance_options {first_word_fall_through} ] [get_ips async_fifo_data]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/async_fifo_data/async_fifo_data.xci]

# Adding an Asynchronous FIFO Signal IP
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name async_fifo_signal
set_property -dict [list \
    CONFIG.fifo_implementation {independent_clocks_distributed_ram} \
    CONFIG.synchronization_stages {3} \
    CONFIG.input_data_width {1} \
    CONFIG.input_depth {16} \
    CONFIG.reset_pin {false} \
    CONFIG.performance_options {first_word_fall_through} ] [get_ips async_fifo_signal]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/async_fifo_signal/async_fifo_signal.xci]

# Adding a Clock Wizard IP
# For some platforms, you may have to set CONFIG.PRIM_SOURCE {No_buffer}
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.00000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.00000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {166.66667} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {200.00000} \
    CONFIG.CLKOUT4_USED {false} \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_LOCKED {false}] [get_ips clk_wiz_0]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xci]

# Adding an SPI IP
create_ip -name axi_quad_spi -vendor xilinx.com -library ip -module_name axi_quad_spi_0
set_property -dict [ list \
   CONFIG.C_FIFO_DEPTH {256} \
   CONFIG.C_SCK_RATIO {4} \
   CONFIG.C_USE_STARTUP {0} \
   CONFIG.C_USE_STARTUP_INT {0} \
   CONFIG.QSPI_BOARD_INTERFACE {custom}] [get_ips axi_quad_spi_0]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/axi_quad_spi_0/axi_quad_spi_0.xci]

# Adding an MIG IP
create_ip -name mig_7series -vendor xilinx.com -library ip -module_name mig_7series_0
file copy $source_dir/mig/$mig_file ${proj_name}/${proj_name}.srcs/sources_1/ip/mig_7series_0/mig.prj
set_property -dict [list CONFIG.XML_INPUT_FILE {mig.prj}] [get_ips mig_7series_0]
generate_target {instantiation_template} [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/mig_7series_0/mig_7series_0.xci]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/mig_7series_0/mig_7series_0.xci]

# Adding Floating Point IPs
create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Add_Sub_S
set_property -dict [list \
    CONFIG.Operation_Type {Add_Subtract} \
    CONFIG.Add_Sub_Value {Add} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_Add_Sub_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Add_Sub_S/FP_Add_Sub_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Mul_S
set_property -dict [list \
    CONFIG.Operation_Type {Multiply} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_Mul_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Mul_S/FP_Mul_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Div_S
set_property -dict [list \
    CONFIG.Operation_Type {Divide} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_Div_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Div_S/FP_Div_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Sqrt_S
set_property -dict [list \
    CONFIG.Operation_Type {Square_root} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_Sqrt_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Sqrt_S/FP_Sqrt_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CmpLT_S
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Custom} \
    CONFIG.C_Compare_Operation {Less_Than} ] [get_ips FP_CmpLT_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CmpLT_S/FP_CmpLT_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_MAddSub_S
set_property -dict [list \
    CONFIG.Operation_Type {FMA} \
    CONFIG.Add_Sub_Value {Add} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_MAddSub_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_MAddSub_S/FP_MAddSub_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_W_S
set_property -dict [list \
    CONFIG.Operation_Type {Float_to_fixed} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Int32} ] [get_ips FP_CVT_W_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_W_S/FP_CVT_W_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_EQ_S
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Custom} \
    CONFIG.C_Compare_Operation {Equal} ] [get_ips FP_EQ_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_EQ_S/FP_EQ_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_S_W
set_property -dict [list \
    CONFIG.Operation_Type {Fixed_to_float} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Int32} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_CVT_S_W]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_S_W/FP_CVT_S_W.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_S_WU
set_property -dict [list \
    CONFIG.Operation_Type {Fixed_to_float} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Uint32} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_CVT_S_WU]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_S_WU/FP_CVT_S_WU.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_LE_S
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Custom} \
    CONFIG.C_Compare_Operation {Less_Than_Or_Equal} ] [get_ips FP_LE_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_LE_S/FP_LE_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Add_Sub_D
set_property -dict [list \
    CONFIG.Operation_Type {Add_Subtract} \
    CONFIG.Add_Sub_Value {Add} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_Add_Sub_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Add_Sub_D/FP_Add_Sub_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Mul_D
set_property -dict [list \
    CONFIG.Operation_Type {Multiply} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_Mul_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Mul_D/FP_Mul_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Div_D
set_property -dict [list \
    CONFIG.Operation_Type {Divide} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_Div_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Div_D/FP_Div_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_Sqrt_D
set_property -dict [list \
    CONFIG.Operation_Type {Square_root} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_Sqrt_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_Sqrt_D/FP_Sqrt_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CmpLT_D
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Custom} \
    CONFIG.C_Compare_Operation {Less_Than} ] [get_ips FP_CmpLT_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CmpLT_D/FP_CmpLT_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_MAddSub_D
set_property -dict [list \
    CONFIG.Operation_Type {FMA} \
    CONFIG.Add_Sub_Value {Add} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_MAddSub_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_MAddSub_D/FP_MAddSub_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_W_D
set_property -dict [list \
    CONFIG.Operation_Type {Float_to_fixed} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Int32} ] [get_ips FP_CVT_W_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_W_D/FP_CVT_W_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_EQ_D
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Custom} \
    CONFIG.C_Compare_Operation {Equal} ] [get_ips FP_EQ_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_EQ_D/FP_EQ_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_LE_D
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Custom} \
    CONFIG.C_Compare_Operation {Less_Than_Or_Equal} ] [get_ips FP_LE_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_LE_D/FP_LE_D.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_D_W
set_property -dict [list \
    CONFIG.Operation_Type {Fixed_to_float} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Int32} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_CVT_D_W]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_D_W/FP_CVT_D_W.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_D_WU
set_property -dict [list \
    CONFIG.Operation_Type {Fixed_to_float} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Uint32} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_CVT_D_WU]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_D_WU/FP_CVT_D_WU.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_D_S
set_property -dict [list \
    CONFIG.Operation_Type {Float_to_float} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Double} ] [get_ips FP_CVT_D_S]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_D_S/FP_CVT_D_S.xci]

create_ip -name floating_point -vendor xilinx.com -library ip -module_name FP_CVT_S_D
set_property -dict [list \
    CONFIG.Operation_Type {Float_to_float} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.A_Precision_Type {Double} \
    CONFIG.Result_Precision_Type {Single} ] [get_ips FP_CVT_S_D]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/FP_CVT_S_D/FP_CVT_S_D.xci]

# ===========================================================================================
#  End of wrokspace creation.
# ===========================================================================================
puts "INFO: Project created:${proj_name}"

# Open current project with Vivado GUI
start_gui
