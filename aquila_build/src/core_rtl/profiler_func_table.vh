// =============================================================================
//  File: profiler_func_table.vh
//  自動生成的 Profiler 函式位址表
//  
//  *** 請勿手動編輯此檔案 ***
//  
//  此檔案由 generate_profiler_table.sh 自動生成
//  來源: RISC-V CoreMark ELF 檔案
//  目的: 提供 FPGA 硬體 Profiler 的函式位址範圍
//
//  生成時間: Tue Oct  7 03:55:22 PM CST 2025
//  ELF 檔案: coremark.elf
//  
//  使用方式: 在 Verilog 模組中使用 `include "profiler_func_table.vh"
// 
//  注意事項:
//  - 位址範圍使用半開區間 [START, END)
//  - 函式判斷條件: (pc >= START) && (pc < END)
//  - 每次重新編譯 CoreMark 後需重新生成此檔案
// =============================================================================

// Function 0: core_list_reverse (熱點佔比: 26.22%)
`define FUNC0_NAME "core_list_reverse"
`define FUNC0_START 32'h00001f5c
`define FUNC0_END   32'h0000205c  // 半開區間，不包含此位址

// Function 1: core_list_find (熱點佔比: 25.36%)
`define FUNC1_NAME "core_list_find"
`define FUNC1_START 32'h00001f10
`define FUNC1_END   32'h00002010  // 半開區間，不包含此位址

// Function 2: matrix_mul_matrix_bitextract (熱點佔比: 10.17%)
`define FUNC2_NAME "matrix_mul_matrix_bitextract"
`define FUNC2_START 32'h000028b8
`define FUNC2_END   32'h000029b8  // 半開區間，不包含此位址

// Function 3: core_state_transition (熱點佔比: 7.88%)
`define FUNC3_NAME "core_state_transition"
`define FUNC3_START 32'h00002dec
`define FUNC3_END   32'h00002eec  // 半開區間，不包含此位址

// Function 4: crcu8 (熱點佔比: 6.88%)
`define FUNC4_NAME "crcu8"
`define FUNC4_START 32'h00001adc
`define FUNC4_END   32'h00001bdc  // 半開區間，不包含此位址

// =============================================================================
// 函式列表摘要
// =============================================================================
//
//  FUNC0: core_list_reverse                   [0x00001f5c, 0x0000205c)   256 bytes  26.22%
//  FUNC1: core_list_find                      [0x00001f10, 0x00002010)   256 bytes  25.36%
//  FUNC2: matrix_mul_matrix_bitextract        [0x000028b8, 0x000029b8)   256 bytes  10.17%
//  FUNC3: core_state_transition               [0x00002dec, 0x00002eec)   256 bytes  7.88%
//  FUNC4: crcu8                               [0x00001adc, 0x00001bdc)   256 bytes  6.88%
//
// =============================================================================
