`timescale 1ns / 1ps
// =============================================================================
//  Program : profiler.v
//  Author  : HW1 Student
//  Date    : Oct/06/2025
// -----------------------------------------------------------------------------
//  Description:
//  Hardware profiler for CoreMark benchmark analysis.
//  Tracks execution cycles for top 5 hotspot functions and distinguishes
//  between compute cycles and memory cycles.
//
//  Features:
//  - 5 function range detectors with cycle counters
//  - Per-function compute/memory cycle breakdown
//  - Global compute/memory cycle counters
//  - Total cycle counter
//  - Stall cycle tracking for memory operations
// -----------------------------------------------------------------------------

module profiler #(
    parameter XLEN = 32,
    parameter NUM_FUNCTIONS = 5
)(
    input                   clk_i,
    input                   rst_i,
    
    // Signals from pipeline stages
    input  [XLEN-1 : 0]     exe2mem_pc_i,          // PC from Execute stage
    input                   exe_valid_i,           // Execute stage is valid
    input                   exe_re_i,              // Load instruction (read enable)
    input                   exe_we_i,              // Store instruction (write enable)
    
    // Stall signals from different sources
    input                   stall_instr_fetch_i,   // Stall from instruction fetch
    input                   stall_data_fetch_i,    // Stall from data memory fetch
    input                   stall_from_exe_i,      // Stall from muldiv operations
    input                   stall_data_hazard_i,   // Stall from data hazard
    
    // Profiler control
    input                   profiler_enable_i,     // Enable profiling
    input                   profiler_reset_i,      // Reset all counters
    
    // Counter outputs (for ILA observation)
    output reg [63:0]       total_cycles_o,
    output reg [63:0]       func0_cycles_o,
    output reg [63:0]       func1_cycles_o,
    output reg [63:0]       func2_cycles_o,
    output reg [63:0]       func3_cycles_o,
    output reg [63:0]       func4_cycles_o,
    
    output reg [63:0]       func0_compute_cycles_o,
    output reg [63:0]       func1_compute_cycles_o,
    output reg [63:0]       func2_compute_cycles_o,
    output reg [63:0]       func3_compute_cycles_o,
    output reg [63:0]       func4_compute_cycles_o,
    
    output reg [63:0]       func0_memory_cycles_o,
    output reg [63:0]       func1_memory_cycles_o,
    output reg [63:0]       func2_memory_cycles_o,
    output reg [63:0]       func3_memory_cycles_o,
    output reg [63:0]       func4_memory_cycles_o,
    
    output reg [63:0]       global_compute_cycles_o,
    output reg [63:0]       global_memory_cycles_o,
    
    // Detailed stall cycle counters
    output reg [63:0]       stall_instr_fetch_cycles_o,  // Instruction fetch stall cycles
    output reg [63:0]       stall_data_fetch_cycles_o,   // Data memory fetch stall cycles
    output reg [63:0]       stall_muldiv_cycles_o,       // Muldiv operation stall cycles
    output reg [63:0]       stall_data_hazard_cycles_o,  // Data hazard stall cycles
    
    // Debug outputs
    output reg [4:0]        current_function_o,  // Which function is executing (one-hot + none)
    output wire             is_memory_cycle_o,   // Current cycle is memory cycle
    output wire [3:0]       stall_type_o,        // Type of stall (one-hot)
    
    // PC-Based Debug Outputs for Advanced Triggering
    output wire             pc_in_func_range_debug,    // PC在任何函式範圍內
    output wire [2:0]       pc_region_debug,           // PC所在區域編碼
    output wire             pc_above_funcs_debug,      // PC高於所有函式範圍
    output wire             pc_below_funcs_debug,      // PC低於所有函式範圍
    output wire             coremark_likely_ended_debug // CoreMark可能已結束
);

// -----------------------------------------------------------------------------
// 函式位址範圍（來自 RISC-V CoreMark ELF，用於 FPGA 上板）
// -----------------------------------------------------------------------------
// *** 重要說明 ***
// 
// 位址來源：
//   - 這些位址是從 RISC-V CoreMark ELF 檔案自動提取
//   - 用於 FPGA 上板後的實際硬體分析（非 Linux x86 模擬）
//   - 每次重新編譯 CoreMark 後必須重新生成位址表
//
// 自動生成流程：
//   1. 編譯 CoreMark: cd aquila_sw/CoreMark && make
//   2. 生成位址表: ./generate_profiler_table.sh
//   3. 檢查生成檔案: aquila_build/src/core_rtl/profiler_func_table.vh
//
// 位址範圍格式：
//   - 使用半開區間 [START, END)
//   - START: 函式的起始位址（包含）
//   - END: 下一個函式的起始位址（不包含）
//   - 判斷條件: (pc >= START) && (pc < END)
//
// *** 請勿手動編輯位址，請使用 generate_profiler_table.sh 重新生成 ***
// -----------------------------------------------------------------------------

// 引入自動生成的函式位址表
`include "profiler_func_table.vh"

// 將 define 轉換為 localparam 供模組使用
// 注意：END 位址使用半開區間，不包含在函式範圍內
localparam [XLEN-1:0] FUNC0_START = `FUNC0_START;
localparam [XLEN-1:0] FUNC0_END   = `FUNC0_END;  // 半開區間，不包含

localparam [XLEN-1:0] FUNC1_START = `FUNC1_START;
localparam [XLEN-1:0] FUNC1_END   = `FUNC1_END;  // 半開區間，不包含

localparam [XLEN-1:0] FUNC2_START = `FUNC2_START;
localparam [XLEN-1:0] FUNC2_END   = `FUNC2_END;  // 半開區間，不包含

localparam [XLEN-1:0] FUNC3_START = `FUNC3_START;
localparam [XLEN-1:0] FUNC3_END   = `FUNC3_END;  // 半開區間，不包含

localparam [XLEN-1:0] FUNC4_START = `FUNC4_START;
localparam [XLEN-1:0] FUNC4_END   = `FUNC4_END;  // 半開區間，不包含

// -----------------------------------------------------------------------------
// 函式範圍檢測（半開區間 [START, END)）
// -----------------------------------------------------------------------------
// 使用 Execute stage 的 PC (exe2mem_pc_i) 進行判斷
// 使用半開區間確保：
//   1. 不會與相鄰函式重疊
//   2. 精確匹配函式的實際指令範圍
//   3. 符合標準的區間表示法
wire in_func0 = (exe2mem_pc_i >= FUNC0_START) && (exe2mem_pc_i < FUNC0_END);
wire in_func1 = (exe2mem_pc_i >= FUNC1_START) && (exe2mem_pc_i < FUNC1_END);
wire in_func2 = (exe2mem_pc_i >= FUNC2_START) && (exe2mem_pc_i < FUNC2_END);
wire in_func3 = (exe2mem_pc_i >= FUNC3_START) && (exe2mem_pc_i < FUNC3_END);
wire in_func4 = (exe2mem_pc_i >= FUNC4_START) && (exe2mem_pc_i < FUNC4_END);

wire in_any_function = in_func0 | in_func1 | in_func2 | in_func3 | in_func4;

// ========== PC Range Analysis for Advanced Triggering ==========
// 檢測PC是否在任何函式範圍內
wire pc_in_functions = in_any_function;

// PC區域編碼 (3-bit)：
// 000: PC < 0x1000 (可能是初始化階段)
// 001: 0x1000 <= PC < 0x1adc (程式執行但未到函式)
// 010: 0x1adc <= PC <= 0x2eec (在函式範圍內)
// 011: 0x2eec < PC < 0x10000 (函式執行完畢)
// 100: PC >= 0x10000 (可能回到主程式或結束)
wire [2:0] pc_region_encode;
assign pc_region_encode = (exe2mem_pc_i < 32'h00001000) ? 3'b000 :
                         (exe2mem_pc_i < 32'h00001adc) ? 3'b001 :
                         (exe2mem_pc_i <= 32'h00002eec) ? 3'b010 :
                         (exe2mem_pc_i < 32'h00010000) ? 3'b011 :
                                                        3'b100;

// PC位置檢測
wire pc_above_funcs = (exe2mem_pc_i > 32'h00002eec);  // PC高於所有函式
wire pc_below_funcs = (exe2mem_pc_i < 32'h00001adc);  // PC低於所有函式

// CoreMark可能結束的條件：
// 1. PC跳出函式範圍且到達較高地址 (> 0x10000)
// 2. 或者PC回到很低的地址但已執行過函式 (< 0x1000 但總cycle數很大)
wire coremark_likely_ended = (exe2mem_pc_i > 32'h00010000) ||
                            ((exe2mem_pc_i < 32'h00001000) && (total_cycles_o > 64'd1000000));

// -----------------------------------------------------------------------------
// Memory cycle and Stall detection
// -----------------------------------------------------------------------------
// Memory cycles include:
// 1. Load/Store instruction execution cycles (exe_re_i or exe_we_i)
// 2. Data memory fetch stall cycles (stall_data_fetch_i)
// 
// Stall categorization:
// - stall_instr_fetch_i: Instruction fetch stall (instruction cache miss, etc.)
// - stall_data_fetch_i:  Data memory fetch stall (data cache miss, DRAM latency)
// - stall_from_exe_i:    Muldiv operation stall
// - stall_data_hazard_i: Data hazard stall (load-use hazard, etc.)
// -----------------------------------------------------------------------------

// Load/Store instruction detection
wire is_load_store = exe_re_i | exe_we_i;

// Memory cycle: Load/Store execution or data fetch stall
wire is_memory_cycle = (is_load_store & exe_valid_i) | stall_data_fetch_i;

// Compute cycle: Valid execution cycle that is not a memory cycle and not stalled
wire is_compute_cycle = exe_valid_i & ~is_memory_cycle & 
                        ~stall_instr_fetch_i & ~stall_from_exe_i & ~stall_data_hazard_i;

// Stall type detection (one-hot encoding)
// [3]: instruction fetch, [2]: data fetch, [1]: muldiv, [0]: data hazard
assign stall_type_o = {stall_instr_fetch_i, stall_data_fetch_i, 
                       stall_from_exe_i, stall_data_hazard_i};

assign is_memory_cycle_o = is_memory_cycle;

// ========== PC-Based Debug Output Assignments ==========
assign pc_in_func_range_debug = pc_in_functions;
assign pc_region_debug = pc_region_encode;
assign pc_above_funcs_debug = pc_above_funcs;
assign pc_below_funcs_debug = pc_below_funcs;
assign coremark_likely_ended_debug = coremark_likely_ended;

// One-hot encoding of current function (bit 4 = none)
always @(*) begin
    if (in_func0)
        current_function_o = 5'b00001;
    else if (in_func1)
        current_function_o = 5'b00010;
    else if (in_func2)
        current_function_o = 5'b00100;
    else if (in_func3)
        current_function_o = 5'b01000;
    else if (in_func4)
        current_function_o = 5'b10000;
    else
        current_function_o = 5'b00000; // Not in any tracked function
end

// -----------------------------------------------------------------------------
// Cycle counters
// -----------------------------------------------------------------------------
always @(posedge clk_i) begin
    if (rst_i || profiler_reset_i) begin
        // Reset all counters
        total_cycles_o <= 64'h0;
        
        func0_cycles_o <= 64'h0;
        func1_cycles_o <= 64'h0;
        func2_cycles_o <= 64'h0;
        func3_cycles_o <= 64'h0;
        func4_cycles_o <= 64'h0;
        
        func0_compute_cycles_o <= 64'h0;
        func1_compute_cycles_o <= 64'h0;
        func2_compute_cycles_o <= 64'h0;
        func3_compute_cycles_o <= 64'h0;
        func4_compute_cycles_o <= 64'h0;
        
        func0_memory_cycles_o <= 64'h0;
        func1_memory_cycles_o <= 64'h0;
        func2_memory_cycles_o <= 64'h0;
        func3_memory_cycles_o <= 64'h0;
        func4_memory_cycles_o <= 64'h0;
        
        global_compute_cycles_o <= 64'h0;
        global_memory_cycles_o <= 64'h0;
        
        // Reset stall counters
        stall_instr_fetch_cycles_o <= 64'h0;
        stall_data_fetch_cycles_o <= 64'h0;
        stall_muldiv_cycles_o <= 64'h0;
        stall_data_hazard_cycles_o <= 64'h0;
    end
    else if (profiler_enable_i) begin
        // Total cycles counter (always incrementing when enabled)
        total_cycles_o <= total_cycles_o + 64'h1;
        
        // Global compute/memory counters
        if (is_compute_cycle)
            global_compute_cycles_o <= global_compute_cycles_o + 64'h1;
        if (is_memory_cycle)
            global_memory_cycles_o <= global_memory_cycles_o + 64'h1;
        
        // Stall type counters
        if (stall_instr_fetch_i)
            stall_instr_fetch_cycles_o <= stall_instr_fetch_cycles_o + 64'h1;
        if (stall_data_fetch_i)
            stall_data_fetch_cycles_o <= stall_data_fetch_cycles_o + 64'h1;
        if (stall_from_exe_i)
            stall_muldiv_cycles_o <= stall_muldiv_cycles_o + 64'h1;
        if (stall_data_hazard_i)
            stall_data_hazard_cycles_o <= stall_data_hazard_cycles_o + 64'h1;
        
        // Per-function counters (only count when instruction is valid in execute stage)
        if (in_func0 && exe_valid_i) begin
            func0_cycles_o <= func0_cycles_o + 64'h1;
            if (is_compute_cycle)
                func0_compute_cycles_o <= func0_compute_cycles_o + 64'h1;
            if (is_memory_cycle)
                func0_memory_cycles_o <= func0_memory_cycles_o + 64'h1;
        end
        
        if (in_func1 && exe_valid_i) begin
            func1_cycles_o <= func1_cycles_o + 64'h1;
            if (is_compute_cycle)
                func1_compute_cycles_o <= func1_compute_cycles_o + 64'h1;
            if (is_memory_cycle)
                func1_memory_cycles_o <= func1_memory_cycles_o + 64'h1;
        end
        
        if (in_func2 && exe_valid_i) begin
            func2_cycles_o <= func2_cycles_o + 64'h1;
            if (is_compute_cycle)
                func2_compute_cycles_o <= func2_compute_cycles_o + 64'h1;
            if (is_memory_cycle)
                func2_memory_cycles_o <= func2_memory_cycles_o + 64'h1;
        end
        
        if (in_func3 && exe_valid_i) begin
            func3_cycles_o <= func3_cycles_o + 64'h1;
            if (is_compute_cycle)
                func3_compute_cycles_o <= func3_compute_cycles_o + 64'h1;
            if (is_memory_cycle)
                func3_memory_cycles_o <= func3_memory_cycles_o + 64'h1;
        end
        
        if (in_func4 && exe_valid_i) begin
            func4_cycles_o <= func4_cycles_o + 64'h1;
            if (is_compute_cycle)
                func4_compute_cycles_o <= func4_compute_cycles_o + 64'h1;
            if (is_memory_cycle)
                func4_memory_cycles_o <= func4_memory_cycles_o + 64'h1;
        end
    end
end

// Mark critical signals for ILA debugging
(* mark_debug = "true" *) reg [63:0] total_cycles_debug;
(* mark_debug = "true" *) reg [63:0] func0_cycles_debug;
(* mark_debug = "true" *) reg [63:0] func1_cycles_debug;
(* mark_debug = "true" *) reg [63:0] func2_cycles_debug;
(* mark_debug = "true" *) reg [63:0] func3_cycles_debug;
(* mark_debug = "true" *) reg [63:0] func4_cycles_debug;
(* mark_debug = "true" *) reg [31:0] exe_pc_debug;
(* mark_debug = "true" *) reg [4:0]  current_function_debug;
(* mark_debug = "true" *) reg        is_memory_cycle_debug;
(* mark_debug = "true" *) reg [3:0]  stall_type_debug;
(* mark_debug = "true" *) reg [63:0] stall_instr_fetch_debug;
(* mark_debug = "true" *) reg [63:0] stall_data_fetch_debug;
(* mark_debug = "true" *) reg [63:0] stall_muldiv_debug;
(* mark_debug = "true" *) reg [63:0] stall_data_hazard_debug;

// ========== PC-Based Debug Signals for Advanced Triggering ==========
(* mark_debug = "true" *) (* keep = "true" *) reg        pc_in_func_range_ila;      // PC在任何函式範圍內 (ILA專用)
(* mark_debug = "true" *) (* keep = "true" *) reg [2:0]  pc_region_ila;             // PC所在區域編碼 (ILA專用)
(* mark_debug = "true" *) (* keep = "true" *) reg        pc_above_funcs_ila;        // PC高於所有函式範圍 (ILA專用)
(* mark_debug = "true" *) (* keep = "true" *) reg        pc_below_funcs_ila;        // PC低於所有函式範圍 (ILA專用)
(* mark_debug = "true" *) (* keep = "true" *) reg        coremark_likely_ended_ila; // CoreMark可能已結束 (ILA專用)

always @(posedge clk_i) begin
    total_cycles_debug <= total_cycles_o;
    func0_cycles_debug <= func0_cycles_o;
    func1_cycles_debug <= func1_cycles_o;
    func2_cycles_debug <= func2_cycles_o;
    func3_cycles_debug <= func3_cycles_o;
    func4_cycles_debug <= func4_cycles_o;
    exe_pc_debug <= exe2mem_pc_i;
    current_function_debug <= current_function_o;
    is_memory_cycle_debug <= is_memory_cycle_o;
    stall_type_debug <= stall_type_o;
    stall_instr_fetch_debug <= stall_instr_fetch_cycles_o;
    stall_data_fetch_debug <= stall_data_fetch_cycles_o;
    stall_muldiv_debug <= stall_muldiv_cycles_o;
    stall_data_hazard_debug <= stall_data_hazard_cycles_o;
    
    // ========== PC-Based Debug Signals ==========
    pc_in_func_range_ila <= pc_in_functions;
    pc_region_ila <= pc_region_encode;
    pc_above_funcs_ila <= pc_above_funcs;
    pc_below_funcs_ila <= pc_below_funcs;
    coremark_likely_ended_ila <= coremark_likely_ended;
end

endmodule

