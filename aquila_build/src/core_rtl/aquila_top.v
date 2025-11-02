`timescale 1 ns / 1 ps
// =============================================================================
//  Program : aquila_top.v
//  Author  : Chun-Jen Tsai
//  Date    : Oct/08/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the top-level Aquila core wrapper. The Aquila core contains six IPs:
//    1) The RISC-V Pipeline
//    2) The CLINT timer interrupt generator
//    3) The Atomic Unit
//    4) The L1 instruction cache
//    5) The L1 data cache
//    6) The Tightly-Coupled Memory (TCM), aka, scratchpad memory
//
//  These IPs are connected via a simple memory-mapped bus protocol.
//  The Aquila core can be connected to external AXI-based devices via
//  the Core2AXI_if interface bridge module at the SoC level.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  This module is based on the soc_top.v module written by Jin-you Wu
//  on Feb/28/2019. The original module was a stand-alone top-level module
//  for an SoC. This rework makes it a module embedded inside an AXI IP.
//
//  Jan/12/2020, by Chun-Jen Tsai:
//    Added a on-chip Tightly-Coupled Memory (TCM) to the aquila SoC.
//
//  Mar/05/2020, by Chih-Yu Hsiang:
//    Support for A standard extension.
//
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019 -,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Yang Ming Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
`include "aquila_config.vh"

module aquila_top #
(
    parameter integer HART_ID  = 0,
    parameter integer XLEN     = 32,  // Width of RISCV registers.
    parameter integer CLSIZE   = `CLP // Size of a cache block in bits.
)
(
    input                 clk_i,
    input                 rst_i,   // level-sensitive reset signal.

    // Initial program counter address for the Aquila core
    input  [XLEN-1 : 0]   base_addr_i,

    // Aquila external instruction memory interface signals
    output                M_IMEM_strobe_o,
    output [XLEN-1 : 0]   M_IMEM_addr_o,
    input                 M_IMEM_done_i,
    input  [CLSIZE-1 : 0] M_IMEM_data_i,

    // Aquila external data memory interface signals
    output                M_DMEM_strobe_o,
    output [XLEN-1 : 0]   M_DMEM_addr_o,
    output                M_DMEM_rw_o,
    output [CLSIZE-1 : 0] M_DMEM_data_o,
    input                 M_DMEM_done_i,
    input  [CLSIZE-1 : 0] M_DMEM_data_i,

    // Aquila M_DEVICE master port interface signals
    output                M_DEVICE_strobe_o,
    output [XLEN-1 : 0]   M_DEVICE_addr_o,
    output                M_DEVICE_rw_o,
    output [XLEN/8-1 : 0] M_DEVICE_byte_enable_o,
    output [XLEN-1 : 0]   M_DEVICE_data_o,
    input                 M_DEVICE_data_ready_i,
    input  [XLEN-1 : 0]   M_DEVICE_data_i,

    // External interrupt requests from I/O devices
    input                 ext_irq_i
);

// ------------- Signals for cpu, cache and master ip -------------------------
// CPU core
wire                      code_sel;
wire [1 : 0]              data_sel;

// Cache flush signals
wire                      p_cache_flush;
wire                      dcache_flushing;

// Processor to instruction memory signals.
wire                      p_i_strobe;
wire                      p_i_ready;
wire [XLEN-1 : 0]         p_i_addr;
wire [XLEN-1 : 0]         p_i_code;

wire [XLEN-1 : 0]         code_from_tcm;
wire [XLEN-1 : 0]         code_from_cache;
wire                      tcm_i_ready;
wire                      cache_i_ready;

// Processor to data memory signals.
wire                      p_d_strobe;
wire                      p_d_ready;
wire [XLEN-1 : 0]         p_d_addr;
wire                      p_d_rw;
wire [XLEN/8-1 : 0]       p_d_byte_enable;
wire [XLEN-1 : 0]         p_d_mem2core;
wire [XLEN-1 : 0]         p_d_core2mem;

wire                      p_d_is_amo;    // Is it an atomic data access?
wire [4 : 0]              p_d_amo_type;  // Type of the atomic data access.

wire [XLEN-1 : 0]         data_from_tcm;
wire [XLEN-1 : 0]         data_from_cache;
wire                      tcm_d_ready;
wire                      cache_d_ready;

// I/D Caches to DDRx memory signals.
wire                      m_i_strobe, m_i_ready;
wire                      m_d_strobe, m_d_rw, m_d_ready;
wire [XLEN-1 : 0]         m_i_addr, m_d_addr;
wire [CLSIZE-1 : 0]       m_i_dram, m_d_cache2dram, m_d_dram2cache;

`ifdef ENABLE_ATOMIC_UNIT
wire                      m_d_is_amo;   // Atomic op flag to D-memory.
wire [4 : 0]              m_d_amo_type; // Atomic type to D-memory.

// Connections from the RISCV Core to the Atomic Unit, then to D-memory.
wire                      atomic_unit_strobe;
wire [XLEN-1 : 0]         atomic_unit_addr;
wire                      atomic_unit_rw;
wire [CLSIZE-1 : 0]       atomic_unit_dataout;
wire                      atomic_unit_done;
wire [CLSIZE-1 : 0]       atomic_unit_datain;
`endif

// Interrupt signals.
wire tmr_irq, sft_irq;

// The processor pipeline cannot be interrupted when
// external memory or device accesses is in progress.
wire is_ext_addr = (data_sel != 2'b0);

// System device data bus.
wire [XLEN-1 : 0]         data_from_sysdev;
wire                      sysdev_d_ready;

// ------ System Memory Map: DDRx DRAM, I/O Devices, or System Devices ---------
//       [0] 0x0000_0000 - 0x0FFF_FFFF : Tightly-Coupled Memory (TCM)
//       [1] 0x8000_0000 - 0xBFFF_FFFF : DDRx DRAM memory (cached)
//       [2] 0xC000_0000 - 0xCFFF_FFFF : device memory (uncached)
//       [3] 0xF000_0000 - 0xFFFF_FFFF : System devices (uncached)
//
wire [3 : 0] code_segment, data_segment;

assign code_segment = p_i_addr[XLEN-1:XLEN-4];
assign data_segment = p_d_addr[XLEN-1:XLEN-4];

assign code_sel = (code_segment == 4'h0)? 0 : 1;
assign data_sel = (data_segment == 4'h0)? 0 :
                  (data_segment == 4'hC)? 2 :
                  (data_segment == 4'hF)? 3 : 1;

assign p_i_code = (code_sel == 0)? code_from_tcm : code_from_cache;
assign p_i_ready = (code_sel == 0)? tcm_i_ready : cache_i_ready;

reg  [1:0] data_sel_r;
always @(posedge clk_i) begin
	data_sel_r <= data_sel;
end

// Delay the memory response by one clock cycle so that
//   the processor core will not miss the ready strobe.
assign p_d_mem2core = (data_sel_r == 0)? data_from_tcm :
                      (data_sel_r == 1)? data_from_cache :
                      (data_sel_r == 2)? M_DEVICE_data_i : data_from_sysdev;
assign p_d_ready = (data_sel_r == 0)? tcm_d_ready :
                   (data_sel_r == 1)? cache_d_ready :
                   (data_sel_r == 2)? M_DEVICE_data_ready_i : sysdev_d_ready;

// --- Master IP interface driving signals for I/D caches and I/O devices ---
assign M_IMEM_strobe_o = m_i_strobe;
assign M_IMEM_addr_o   = m_i_addr;
assign m_i_ready       = M_IMEM_done_i;
assign m_i_dram        = M_IMEM_data_i;

// From the Atomic Unit to the external memory controller
`ifdef ENABLE_ATOMIC_UNIT
assign M_DMEM_strobe_o = atomic_unit_strobe;
assign M_DMEM_addr_o   = atomic_unit_addr;
assign M_DMEM_rw_o     = atomic_unit_rw;
assign M_DMEM_data_o   = atomic_unit_dataout;

// From the external memory controller to the atomic unit
assign m_d_ready       = atomic_unit_done;
assign m_d_dram2cache  = atomic_unit_datain;

`else

assign M_DMEM_strobe_o = m_d_strobe;
assign M_DMEM_addr_o   = m_d_addr;
assign M_DMEM_rw_o     = m_d_rw;
assign M_DMEM_data_o   = m_d_cache2dram;

// From the external memory controller to the atomic unit
assign m_d_ready       = M_DMEM_done_i;
assign m_d_dram2cache  = M_DMEM_data_i;
`endif

assign M_DEVICE_strobe_o      = p_d_strobe && (data_sel == 2);
assign M_DEVICE_addr_o        = (data_sel == 2)? p_d_addr : 32'h0;
assign M_DEVICE_rw_o          = p_d_rw && (data_sel == 2);
assign M_DEVICE_byte_enable_o = p_d_byte_enable;
assign M_DEVICE_data_o        = (data_sel == 2)? p_d_core2mem : 32'h0;

// ----------------------------------------------------------------------------
//  Aquila processor core
//
core_top #(.HART_ID(HART_ID), .XLEN(XLEN))
RISCV_CORE0(
    // System signals
    .clk_i(clk_i),
    .rst_i(rst_i),          // from slave register
    .stall_i(1'b0),         // disable user stall signal

    // Program counter address at reset for the Aquila core
    .init_pc_addr_i(base_addr_i),

    // Instruction ports
    .code_i(p_i_code),
    .code_ready_i(p_i_ready),
    .code_addr_o(p_i_addr),
    .code_req_o(p_i_strobe),

    // Data ports
    .data_i(p_d_mem2core),
    .data_ready_i(p_d_ready),
    .data_o(p_d_core2mem),
    .data_addr_o(p_d_addr),
    .data_rw_o(p_d_rw),
    .data_byte_enable_o(p_d_byte_enable),
    .data_req_o(p_d_strobe),
    .data_is_amo_o(p_d_is_amo),
    .data_amo_type_o(p_d_amo_type),
    .data_addr_ext_i(is_ext_addr),

    // Cache flush signal
    .cache_flush_o(p_cache_flush),

    // Interrupt signals
    .ext_irq_i(ext_irq_i), // for external interrupts
    .tmr_irq_i(tmr_irq),
    .sft_irq_i(sft_irq)

    // Profiler debug signals
    // TEMPORARILY COMMENTED OUT - profiler.v related connections
    /*
    .profiler_exe_pc_o(core_exe_pc),
    .profiler_exe_valid_o(core_exe_valid),
    .profiler_exe_re_o(core_exe_re),
    .profiler_exe_we_o(core_exe_we),
    .profiler_stall_instr_fetch_o(core_stall_instr_fetch),
    .profiler_stall_data_fetch_o(core_stall_data_fetch),
    .profiler_stall_from_exe_o(core_stall_from_exe),
    .profiler_stall_data_hazard_o(core_stall_data_hazard),
    */
    
);

// ----------------------------------------------------------------------------
//  Hardware Profiler for CoreMark Analysis
// ----------------------------------------------------------------------------

// Profiler input signals from core_top (connected to RISCV_CORE0)
wire [XLEN-1 : 0] core_exe_pc;           // PC from Execute stage
wire              core_exe_valid;         // Execute stage valid signal
wire              core_exe_re;            // Load instruction indicator
wire              core_exe_we;            // Store instruction indicator
wire              core_stall_instr_fetch; // Instruction fetch stall
wire              core_stall_data_fetch;  // Data memory fetch stall
wire              core_stall_from_exe;    // Muldiv operation stall
wire              core_stall_data_hazard; // Data hazard stall


// TEMPORARILY COMMENTED OUT - profiler.v related signals
/*
// Profiler output signals (visible to ILA for hardware debugging)
wire [63:0] profiler_total_cycles;
wire [63:0] profiler_func0_cycles, profiler_func1_cycles, profiler_func2_cycles;
wire [63:0] profiler_func3_cycles, profiler_func4_cycles;
wire [63:0] profiler_func0_compute, profiler_func1_compute, profiler_func2_compute;
wire [63:0] profiler_func3_compute, profiler_func4_compute;
wire [63:0] profiler_func0_memory, profiler_func1_memory, profiler_func2_memory;
wire [63:0] profiler_func3_memory, profiler_func4_memory;
wire [63:0] profiler_global_compute, profiler_global_memory;
wire [63:0] profiler_stall_instr_fetch_cycles;
wire [63:0] profiler_stall_data_fetch_cycles;
wire [63:0] profiler_stall_muldiv_cycles;
wire [63:0] profiler_stall_data_hazard_cycles;
wire [4:0]  profiler_current_func;        // Current executing function (one-hot)
wire        profiler_is_mem_cycle;        // Current cycle is memory operation
wire [3:0]  profiler_stall_type;          // Type of stall (one-hot)

// ========== New PC-Based Debug Signals for Advanced Triggering ==========
wire        profiler_pc_in_func_range;    // PC在任何函式範圍內
wire [2:0]  profiler_pc_region;           // PC所在區域編碼 (3-bit)
wire        profiler_pc_above_funcs;      // PC高於所有函式範圍
wire        profiler_pc_below_funcs;      // PC低於所有函式範圍
wire        profiler_coremark_likely_ended; // CoreMark可能已結束
*/


// TEMPORARILY COMMENTED OUT - profiler.v related module instantiation
/*
// ----------------------------------------------------------------------------
//  Hardware Profiler Module Instantiation
//  
//  功能：追蹤 CoreMark 前 5 個熱點函式的執行週期
//  
//  輸入來源：
//    - core_exe_pc：從 core_top 的 Execute stage 取得 PC
//    - core_exe_valid：指示 Execute stage 有有效指令
//    - core_exe_re/we：記憶體讀寫指令標記
//    - core_stall_*：各種 pipeline stall 信號
//  
//  輸出用途：
//    - profiler_*_cycles：各種週期計數器（連接到 ILA 進行硬體觀測）
//    - profiler_current_func：當前執行的函式 (one-hot encoding)
//    - profiler_is_mem_cycle：當前週期是否為記憶體操作
//    - profiler_stall_type：當前 stall 類型 (one-hot encoding)
//  
//  函式位址範圍定義於：profiler_func_table.vh (自動生成)
// ----------------------------------------------------------------------------
profiler #(
    .XLEN(XLEN),
    .NUM_FUNCTIONS(5)  // 追蹤前 5 個熱點函式
) PROFILER (
    // ========== System Signals ==========
    .clk_i(clk_i),
    .rst_i(rst_i),
    
    // ========== Pipeline Signals from core_top ==========
    .exe2mem_pc_i(core_exe_pc),          // PC of instruction currently in Execute stage
    .exe_valid_i(core_exe_valid),        // Execute stage valid instruction
    .exe_re_i(core_exe_re),              // Load instruction indicator
    .exe_we_i(core_exe_we),              // Store instruction indicator
    
    // ========== Stall Signals from core_top ==========
    .stall_instr_fetch_i(core_stall_instr_fetch),  // I-cache miss stall
    .stall_data_fetch_i(core_stall_data_fetch),    // D-cache miss stall
    .stall_from_exe_i(core_stall_from_exe),        // Muldiv operation stall
    .stall_data_hazard_i(core_stall_data_hazard),  // Load-use hazard stall
    
    // ========== Profiler Control ==========
    .profiler_enable_i(1'b1),     // Always enabled for continuous profiling
    .profiler_reset_i(1'b0),      // Use system reset only
    
    // ========== Total Cycle Counter ==========
    .total_cycles_o(profiler_total_cycles),
    
    // ========== Per-Function Total Cycle Counters ==========
    .func0_cycles_o(profiler_func0_cycles),  // core_list_reverse
    .func1_cycles_o(profiler_func1_cycles),  // core_list_find
    .func2_cycles_o(profiler_func2_cycles),  // matrix_mul_matrix_bitextract
    .func3_cycles_o(profiler_func3_cycles),  // core_state_transition
    .func4_cycles_o(profiler_func4_cycles),  // crcu8
    
    // ========== Per-Function Compute Cycle Counters ==========
    .func0_compute_cycles_o(profiler_func0_compute),
    .func1_compute_cycles_o(profiler_func1_compute),
    .func2_compute_cycles_o(profiler_func2_compute),
    .func3_compute_cycles_o(profiler_func3_compute),
    .func4_compute_cycles_o(profiler_func4_compute),
    
    // ========== Per-Function Memory Cycle Counters ==========
    .func0_memory_cycles_o(profiler_func0_memory),
    .func1_memory_cycles_o(profiler_func1_memory),
    .func2_memory_cycles_o(profiler_func2_memory),
    .func3_memory_cycles_o(profiler_func3_memory),
    .func4_memory_cycles_o(profiler_func4_memory),
    
    // ========== Global Compute/Memory Cycle Counters ==========
    .global_compute_cycles_o(profiler_global_compute),
    .global_memory_cycles_o(profiler_global_memory),
    
    // ========== Stall Type Cycle Counters ==========
    .stall_instr_fetch_cycles_o(profiler_stall_instr_fetch_cycles),
    .stall_data_fetch_cycles_o(profiler_stall_data_fetch_cycles),
    .stall_muldiv_cycles_o(profiler_stall_muldiv_cycles),
    .stall_data_hazard_cycles_o(profiler_stall_data_hazard_cycles),
    
    // ========== Debug Outputs for ILA ==========
    .current_function_o(profiler_current_func),  // [4:0] one-hot encoding
    .is_memory_cycle_o(profiler_is_mem_cycle),   // Current cycle type
    .stall_type_o(profiler_stall_type),          // [3:0] one-hot encoding
    
    // ========== New PC-Based Debug Outputs for Advanced Triggering ==========
    .pc_in_func_range_debug(profiler_pc_in_func_range),    // PC在任何函式範圍內
    .pc_region_debug(profiler_pc_region),                  // PC所在區域編碼
    .pc_above_funcs_debug(profiler_pc_above_funcs),        // PC高於所有函式範圍
    .pc_below_funcs_debug(profiler_pc_below_funcs),        // PC低於所有函式範圍
    .coremark_likely_ended_debug(profiler_coremark_likely_ended) // CoreMark可能已結束
);
*/


// ----------------------------------------------------------------------------
//  Instiantiation of the dual-port tightly-coupled scratchpad memory module.
//  0x00000000 ~ 0x0FFFFFFF
localparam TCM_ADDR_WIDTH = $clog2(`TCM_SIZE_IN_WORDS);

sram_dp #(.DATA_WIDTH(XLEN), .N_ENTRIES(`TCM_SIZE_IN_WORDS))
TCM(
    // Instruction memory ports
    .clk1_i(clk_i),
    .en1_i(p_i_strobe && (code_sel == 0)),
    .we1_i(1'b0),
    .be1_i(4'b1111),
    .addr1_i(p_i_addr[TCM_ADDR_WIDTH+1 : 2]),
    .data1_i({XLEN{1'b0}}),
    .data1_o(code_from_tcm),
    .ready1_o(tcm_i_ready),

    // Data memory ports
    .clk2_i(clk_i),
    .en2_i(p_d_strobe && (data_sel == 0)),
    .we2_i(p_d_rw && (data_sel == 0)),
    .be2_i(p_d_byte_enable),
    .addr2_i(p_d_addr[TCM_ADDR_WIDTH+1 : 2]),
    .data2_i(p_d_core2mem),  // data from processor write bus
    .data2_o(data_from_tcm),
    .ready2_o(tcm_d_ready)
);

// ----------------------------------------------------------------------------
//  Shared output signals for system devices.
//  Currently, there is only one system device, i.e., CLINT.
wire [3 : 0]      sysdev_sel;
wire [XLEN-1 : 0] clint_dout;
wire              clint_d_ready;

assign sysdev_sel = p_d_addr[19 : 16];
assign data_from_sysdev = (|sysdev_sel)? {XLEN{1'b0}} : clint_dout;
assign sysdev_d_ready = (sysdev_sel == 4'h0)? clint_d_ready // 0xF000_0000 ~ 0xF000_FFFF 
                        : 0;                                // 0xF001_0000 ~ 0xFFFF_FFFF

// ----------------------------------------------------------------------------
//  Instiantiation of the Core Local Interrupt controller (CLINT) module.
//
clint CLINT(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .en_i(sysdev_sel == 4'h0 && (data_sel == 3)),
    .we_i((data_sel == 3) && p_d_rw && p_d_strobe),
    .addr_i(p_d_addr[4 : 2]),
    .data_i(p_d_core2mem),
    .data_o(clint_dout),
    .data_ready_o(clint_d_ready),

    .tmr_irq_o(tmr_irq),
    .sft_irq_o(sft_irq)
);

// ----------------------------------------------------------------------------
//  The Atomic Unit (Overseer of RISCV atomic instructions).
//
// processor to atomic unit
`ifdef ENABLE_ATOMIC_UNIT
atomic_unit ATOM_U(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .core_id_i(1'b1), // number of RISCV cores (# of core_top modules)
    .core_strobe_i(m_d_strobe),
    .core_addr_i(m_d_addr),
    .core_rw_i(m_d_rw),
    .core_data_i(m_d_cache2dram),
    .core_done_o(atomic_unit_done),
    .core_data_o(atomic_unit_datain),

    .core_is_amo_i(m_d_is_amo),
    .core_amo_type_i(m_d_amo_type),

    .M_DMEM_strobe_o(atomic_unit_strobe),
    .M_DMEM_addr_o(atomic_unit_addr),
    .M_DMEM_rw_o(atomic_unit_rw),
    .M_DMEM_data_o(atomic_unit_dataout),
    .M_DMEM_done_i(M_DMEM_done_i),
    .M_DMEM_data_i(M_DMEM_data_i)
);
`endif

`ifdef ENABLE_DDRx_MEMORY
// ----------------------------------------------------------------------------
//  Instiantiation of the I/D-cache modules.
//

// Instruction read from I-cache port.
icache #(.XLEN(XLEN), .CACHE_SIZE(`ICACHE_SIZE), .CLSIZE(CLSIZE))
I_Cache(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .p_strobe_i(p_i_strobe && (code_sel == 1)),
    .p_addr_i(p_i_addr),
    .p_data_o(code_from_cache),
    .p_ready_o(cache_i_ready),
    .p_flush_i(p_cache_flush),

    .m_strobe_o(m_i_strobe),
    .m_addr_o(m_i_addr),
    .m_data_i(m_i_dram),
    .m_ready_i(m_i_ready),

    .d_flushing_i(dcache_flushing)
);

// Data read/write through D-cache port.
dcache #(.XLEN(XLEN), .CACHE_SIZE(`DCACHE_SIZE), .CLSIZE(CLSIZE))
D_Cache(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .p_strobe_i(p_d_strobe && (data_sel == 1)),
    .p_rw_i(p_d_rw && (data_sel == 1)),
    .p_byte_enable_i(p_d_byte_enable),
    .p_addr_i(p_d_addr),
    .p_data_o(data_from_cache),
    .p_data_i(p_d_core2mem),
    .p_ready_o(cache_d_ready),
    .p_flush_i(p_cache_flush),
    .busy_flushing_o(dcache_flushing),

    .p_is_amo_i(p_d_is_amo),
    .p_amo_type_i(p_d_amo_type),
    .m_is_amo_o(m_d_is_amo),
    .m_amo_type_o(m_d_amo_type),

    .m_addr_o(m_d_addr),
    .m_data_i(m_d_dram2cache),
    .m_data_o(m_d_cache2dram),
    .m_strobe_o(m_d_strobe),
    .m_rw_o(m_d_rw),
    .m_ready_i(m_d_ready)
);
`endif

endmodule
