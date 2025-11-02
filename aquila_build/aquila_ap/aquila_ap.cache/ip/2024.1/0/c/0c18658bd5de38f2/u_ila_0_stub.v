// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (lin64) Build 5076996 Wed May 22 18:36:09 MDT 2024
// Date        : Wed Oct 22 00:01:39 2025
// Host        : johnny-VMware-Virtual-Platform running 64-bit Ubuntu 24.04.3 LTS
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ u_ila_0_stub.v
// Design      : u_ila_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2024.1" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(clk, probe0, probe1, probe2, probe3, probe4, probe5, 
  probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13, probe14, probe15)
/* synthesis syn_black_box black_box_pad_pin="probe0[63:0],probe1[63:0],probe2[63:0],probe3[63:0],probe4[63:0],probe5[63:0],probe6[63:0],probe7[63:0],probe8[63:0],probe9[63:0],probe10[63:0],probe11[63:0],probe12[31:0],probe13[63:0],probe14[63:0],probe15[0:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input clk /* synthesis syn_isclock = 1 */;
  input [63:0]probe0;
  input [63:0]probe1;
  input [63:0]probe2;
  input [63:0]probe3;
  input [63:0]probe4;
  input [63:0]probe5;
  input [63:0]probe6;
  input [63:0]probe7;
  input [63:0]probe8;
  input [63:0]probe9;
  input [63:0]probe10;
  input [63:0]probe11;
  input [31:0]probe12;
  input [63:0]probe13;
  input [63:0]probe14;
  input [0:0]probe15;
endmodule
