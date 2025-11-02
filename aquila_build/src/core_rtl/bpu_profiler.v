`timescale 1ns / 1ps
// =============================================================================
//  Program : bpu_profiler.v
//  Author  : HW2 Student - BPU Behavior Analysis
//  Date    : Oct/21/2025
// -----------------------------------------------------------------------------
//  Description:
//  Branch Prediction Unit (BPU) Behavior Analysis Profiler for Aquila Core
//  
//  This profiler collects comprehensive branch prediction statistics including:
//  - Branch prediction accuracy/error types
//  - Branch direction and types (JAL/JALR/conditional branches)
//  - BPU request/response and BHT hit/miss rates  
//  - Misprediction penalty cycles
//  - Global pipeline statistics related to branch prediction
//
//  Designed for TAGE branch predictor analysis and optimization
// -----------------------------------------------------------------------------
//  Features:
//  - Comprehensive branch instruction classification
//  - Detailed prediction accuracy tracking by branch type
//  - BHT utilization and replacement statistics
//  - Misprediction penalty cycle measurement
//  - Real-time statistics for performance optimization
//  - Configurable statistics reset and enable controls
// =============================================================================

module bpu_profiler #(
    parameter XLEN = 32,
    parameter BHT_ENTRY_NUM = 64
)(
    // System signals
    input                       clk_i,
    input                       rst_i,
    
    // Profiler control
    input                       profiler_enable_i,      // Enable BPU profiling
    input                       profiler_reset_i,       // Reset all counters
    
    // =========================================================================
    // BPU Interface Signals (from bpu.v)
    // =========================================================================
    // From Program Counter (Fetch stage)
    input  [XLEN-1:0]           fetch_pc_i,            // PC being fetched
    
    // From BPU prediction interface
    input                       bpu_req_i,             // BPU query request
    input                       bpu_pred_valid_i,      // BPU provides valid prediction
    input                       branch_hit_i,          // BHT hit for current PC
    input                       branch_decision_i,     // BPU prediction (taken/not taken)
    input  [XLEN-1:0]           branch_target_addr_i,  // Predicted target address
    
    // From BPU internal interface (for BHT analysis)
    input  [$clog2(BHT_ENTRY_NUM)-1:0] bht_write_addr_i,   // BHT write address  
    input                       bht_write_enable_i,    // BHT write enable
    
    // =========================================================================
    // Execute Stage Branch Type Signals
    // =========================================================================
    input                       exe_is_jal_i,          // JAL instruction in execute
    input                       exe_is_jalr_i,         // JALR instruction in execute
    input                       exe_is_cond_branch_i,  // Conditional branch in execute
    
    // =========================================================================
    // Execute Stage Signals (Ground Truth)
    // =========================================================================
    input  [XLEN-1:0]           exe_pc_i,              // Execute stage PC
    input                       exe_valid_i,           // Execute stage is valid
    input                       exe_is_branch_i,       // Execute: is branch instruction
    input                       branch_taken_i,        // Execute: actual branch taken
    input                       branch_misprediction_i,// Execute: misprediction detected
    input  [XLEN-1:0]           exe_branch_target_i,   // Execute: actual target address
    
    // =========================================================================
    // Pipeline Control Signals 
    // =========================================================================
    input                       flush_fetch_i,         // Pipeline flush to fetch
    input                       flush_decode_i,        // Pipeline flush to decode
    input                       pipeline_stall_i,      // Pipeline stall signal
    
    // Optional: IF valid on redirect signal (for precise penalty measurement)
    // If not available, connect to 1'b0 and use fallback method
    input                       if_valid_on_redirect_i, // IF hits redirect target and is valid
    
    // =========================================================================
    // BPU Profiler Statistics Outputs
    // =========================================================================
    
    // === Branch Instruction Type Counters ===
    output reg [63:0]           total_branches_o,       // Total branch instructions
    output reg [63:0]           jal_count_o,           // JAL instructions
    output reg [63:0]           jalr_count_o,          // JALR instructions
    output reg [63:0]           cond_branch_count_o,   // Conditional branches
    
    // === Branch Direction Statistics ===
    output reg [63:0]           branches_taken_o,      // Branches actually taken
    output reg [63:0]           branches_not_taken_o,  // Branches not taken
    
    // === BPU Request/Response Statistics ===
    output reg [63:0]           bpu_requests_o,        // Total BPU queries
    output reg [63:0]           bpu_valid_predictions_o,// BPU valid predictions
    output reg [63:0]           bht_hits_o,            // BHT hit count
    output reg [63:0]           bht_misses_o,          // BHT miss count
    output reg [63:0]           bht_updates_o,         // BHT update count
    
    // === Prediction Accuracy Statistics ===
    output reg [63:0]           correct_predictions_o, // Correct predictions
    output reg [63:0]           incorrect_predictions_o,// Incorrect predictions
    
    // === Detailed Misprediction Analysis ===
    output reg [63:0]           false_positive_o,      // Predicted taken, actually not taken
    output reg [63:0]           false_negative_o,      // Predicted not taken, actually taken
    output reg [63:0]           target_mispred_o,      // Correct direction, wrong target
    
    // === Misprediction Penalty Cycles ===
    output reg [63:0]           mispred_penalty_cycles_o,  // Total penalty cycles
    output reg [63:0]           flush_cycles_o,            // Pipeline flush cycles
    
    // === Pipeline Performance Impact ===
    output reg [63:0]           pipeline_stalls_o,     // Pipeline stall cycles
    output reg [63:0]           total_cycles_o,        // Total profiled cycles
    
    // === BHT Utilization Analysis (Optional - Enable with BHT_ANALYSIS_ENABLE) ===
`ifdef BHT_ANALYSIS_ENABLE
    output reg [63:0]           bht_conflicts_o,       // BHT index conflicts
    output reg [31:0]           bht_utilization_o,     // BHT entries used (bitmap sample)
`endif
    
    // === Raw Performance Counters (for software calculation of percentages) ===
    // Software can calculate: (numerator * 100) / denominator
    output reg [63:0]           prediction_accuracy_numerator_o,   // Correct predictions
    output reg [63:0]           prediction_accuracy_denominator_o, // Total predictions
    output reg [63:0]           bht_hit_rate_numerator_o,          // BHT hits
    output reg [63:0]           bht_hit_rate_denominator_o,        // Total BPU requests
    output reg [63:0]           avg_penalty_numerator_o,           // Total penalty cycles
    output reg [63:0]           avg_penalty_denominator_o,         // Total mispredictions
    
    // === CPI Calculation Counters ===
    output reg [63:0]           cpi_numerator_o,                  // Total execution cycles
    output reg [63:0]           cpi_denominator_o                 // Total completed instructions
);

// =============================================================================
// Internal Signals and Registers
// =============================================================================

// =========================================================================
// PC-based Prediction Tracking (Method 1: Most Robust)
// =========================================================================
// FIFO to track predictions with their corresponding PCs
localparam PRED_FIFO_DEPTH = 8;  // Should cover maximum pipeline depth + stalls
localparam PRED_FIFO_PTR_WIDTH = $clog2(PRED_FIFO_DEPTH);

reg [XLEN-1:0]                  pred_fifo_pc [PRED_FIFO_DEPTH-1:0];
reg                             pred_fifo_valid [PRED_FIFO_DEPTH-1:0];
reg                             pred_fifo_decision [PRED_FIFO_DEPTH-1:0];
reg [XLEN-1:0]                  pred_fifo_target [PRED_FIFO_DEPTH-1:0];
reg [PRED_FIFO_PTR_WIDTH-1:0]   pred_fifo_wr_ptr;
/* unused */ // reg [PRED_FIFO_PTR_WIDTH-1:0]   pred_fifo_rd_ptr;

// PC matching for current execute instruction
wire                            exe_pred_match_found;
wire                            exe_pred_valid;
wire                            exe_pred_decision;
wire [XLEN-1:0]                 exe_pred_target;

// Find matching prediction for current execute PC
integer pred_match_idx;
reg temp_match_found;
reg temp_pred_valid;
reg temp_pred_decision;
reg [XLEN-1:0] temp_pred_target;

always @(*) begin
    temp_match_found = 1'b0;
    temp_pred_valid = 1'b0;
    temp_pred_decision = 1'b0;
    temp_pred_target = {XLEN{1'b0}};
    
    // Find first matching entry (priority encoder behavior)
    for (pred_match_idx = 0; pred_match_idx < PRED_FIFO_DEPTH; pred_match_idx = pred_match_idx + 1) begin
        if (!temp_match_found && pred_fifo_valid[pred_match_idx] && (pred_fifo_pc[pred_match_idx] == exe_pc_i)) begin
            temp_match_found = 1'b1;
            temp_pred_valid = 1'b1;
            temp_pred_decision = pred_fifo_decision[pred_match_idx];
            temp_pred_target = pred_fifo_target[pred_match_idx];
            // First match found, subsequent matches will be ignored due to !temp_match_found condition
        end
    end
end

assign exe_pred_match_found = temp_match_found;
assign exe_pred_valid = temp_pred_valid;
assign exe_pred_decision = temp_pred_decision;
assign exe_pred_target = temp_pred_target;

// Misprediction penalty tracking - improved precision
reg                             mispred_detected_ff;
reg                             penalty_counting;
reg [63:0]                      penalty_start_cycle;
wire                            penalty_start;
wire                            penalty_end;

// Penalty period detection
assign penalty_start = branch_misprediction_i && !mispred_detected_ff;

// Improved penalty end condition
assign penalty_end = penalty_counting && 
                    (if_valid_on_redirect_i ||  // Precise method: IF valid on redirect target
                     (!flush_fetch_i && !flush_decode_i && !pipeline_stall_i)); // Fallback method

// BHT conflict detection
reg [$clog2(BHT_ENTRY_NUM)-1:0] last_bht_write_addr;
reg                             bht_write_enable_ff;

// Prediction tracking pipeline
reg                             branch_predicted_ff;
reg                             prediction_decision_ff;
reg [XLEN-1:0]                  predicted_target_ff;

// CPI calculation counters
reg [63:0]                      instruction_completed_count;
reg [63:0]                      execution_cycle_count;

// =============================================================================
// Branch Instruction Classification
// =============================================================================

// Current instruction being executed (using execute stage signals for accuracy)
wire is_branch_instruction = exe_is_branch_i | exe_is_jal_i | exe_is_jalr_i;
wire is_conditional_branch = exe_is_cond_branch_i;
wire is_unconditional_jump = exe_is_jal_i | exe_is_jalr_i;

// =============================================================================
// Misprediction Penalty Cycle Counter
// =============================================================================

// Improved misprediction penalty tracking
always @(posedge clk_i) begin
    if (rst_i) begin
        mispred_detected_ff <= 1'b0;
        penalty_counting <= 1'b0;
        penalty_start_cycle <= 64'b0;
    end else begin
        mispred_detected_ff <= branch_misprediction_i;
        
        // Start penalty period on misprediction
        if (penalty_start) begin
            penalty_counting <= 1'b1;
            penalty_start_cycle <= total_cycles_o;
        end
        // End penalty period when pipeline recovers
        else if (penalty_end) begin
            penalty_counting <= 1'b0;
        end
    end
end

// =============================================================================
// BHT Conflict Detection
// =============================================================================

`ifdef BHT_ANALYSIS_ENABLE
always @(posedge clk_i) begin
    if (rst_i) begin
        last_bht_write_addr <= {$clog2(BHT_ENTRY_NUM){1'b0}};
        bht_write_enable_ff <= 1'b0;
    end else begin
        last_bht_write_addr <= bht_write_addr_i;
        bht_write_enable_ff <= bht_write_enable_i;
    end
end
`endif

`ifdef BHT_ANALYSIS_ENABLE
// Detect BHT conflicts (same index accessed consecutively)
wire bht_conflict = bht_write_enable_i && bht_write_enable_ff && 
                    (bht_write_addr_i == last_bht_write_addr);
`endif

// =============================================================================
// Prediction Pipeline Tracking
// =============================================================================

// =========================================================================
// PC-based Prediction FIFO Management
// =========================================================================
integer fifo_idx;
always @(posedge clk_i) begin
    if (rst_i) begin
        pred_fifo_wr_ptr <= {PRED_FIFO_PTR_WIDTH{1'b0}};
        // pred_fifo_rd_ptr removed as unused
        for (fifo_idx = 0; fifo_idx < PRED_FIFO_DEPTH; fifo_idx = fifo_idx + 1) begin
            pred_fifo_pc[fifo_idx] <= {XLEN{1'b0}};
            pred_fifo_valid[fifo_idx] <= 1'b0;
            pred_fifo_decision[fifo_idx] <= 1'b0;
            pred_fifo_target[fifo_idx] <= {XLEN{1'b0}};
        end
    end else begin
        // Write new prediction when BPU makes a request
        if (bpu_req_i && !pipeline_stall_i) begin
            pred_fifo_pc[pred_fifo_wr_ptr] <= fetch_pc_i;
            pred_fifo_valid[pred_fifo_wr_ptr] <= bpu_pred_valid_i && branch_hit_i;
            pred_fifo_decision[pred_fifo_wr_ptr] <= bpu_pred_valid_i && branch_hit_i ? branch_decision_i : 1'b0;
            pred_fifo_target[pred_fifo_wr_ptr] <= branch_target_addr_i;
            pred_fifo_wr_ptr <= (pred_fifo_wr_ptr + 1'b1 == PRED_FIFO_DEPTH) ? 
                               {PRED_FIFO_PTR_WIDTH{1'b0}} : pred_fifo_wr_ptr + 1'b1;
        end
        
        // Clear matched entries when instruction reaches execute
        if (exe_valid_i && exe_pred_match_found) begin
            for (fifo_idx = 0; fifo_idx < PRED_FIFO_DEPTH; fifo_idx = fifo_idx + 1) begin
                if (pred_fifo_valid[fifo_idx] && (pred_fifo_pc[fifo_idx] == exe_pc_i)) begin
                    pred_fifo_valid[fifo_idx] <= 1'b0;  // Clear this entry
                end
            end
        end
    end
end

// Legacy prediction pipeline tracking (fallback)
always @(posedge clk_i) begin
    if (rst_i) begin
        branch_predicted_ff <= 1'b0;
        prediction_decision_ff <= 1'b0;
        predicted_target_ff <= {XLEN{1'b0}};
    end else if (!pipeline_stall_i) begin
        // Track prediction from fetch stage to execute stage
        // Use bpu_pred_valid_i as gate to avoid branch_hit_i glitches before BPU output ready
        branch_predicted_ff <= bpu_pred_valid_i && branch_hit_i;
        // Miss cases (no valid prediction or BHT miss) are treated as prediction_decision = 0 (not taken)
        prediction_decision_ff <= bpu_pred_valid_i && branch_hit_i ? branch_decision_i : 1'b0;
        predicted_target_ff <= branch_target_addr_i;
    end
end

// =============================================================================
// Statistics Collection
// =============================================================================

always @(posedge clk_i) begin
    if (rst_i || profiler_reset_i) begin
        // Reset all counters
        total_branches_o <= 64'h0;
        jal_count_o <= 64'h0;
        jalr_count_o <= 64'h0;
        cond_branch_count_o <= 64'h0;
        
        branches_taken_o <= 64'h0;
        branches_not_taken_o <= 64'h0;
        
        bpu_requests_o <= 64'h0;
        bpu_valid_predictions_o <= 64'h0;
        bht_hits_o <= 64'h0;
        bht_misses_o <= 64'h0;
        bht_updates_o <= 64'h0;
        
        correct_predictions_o <= 64'h0;
        incorrect_predictions_o <= 64'h0;
        
        false_positive_o <= 64'h0;
        false_negative_o <= 64'h0;
        target_mispred_o <= 64'h0;
        
        mispred_penalty_cycles_o <= 64'h0;
        flush_cycles_o <= 64'h0;
        
        pipeline_stalls_o <= 64'h0;
        total_cycles_o <= 64'h0;
        
        // CPI calculation counters
        instruction_completed_count <= 64'h0;
        execution_cycle_count <= 64'h0;
        
`ifdef BHT_ANALYSIS_ENABLE
        bht_conflicts_o <= 64'h0;
        bht_utilization_o <= 32'h0;
`endif
        
    end else if (profiler_enable_i) begin
        
        // === Total Cycle Counter ===
        total_cycles_o <= total_cycles_o + 64'h1;
        
        // === CPI Calculation Counters ===
        // Execution cycle counter (exclude pipeline stalls)
        if (!pipeline_stall_i) begin
            execution_cycle_count <= execution_cycle_count + 64'h1;
        end
        
        // Instruction completion counter (count valid instructions in execute stage)
        if (exe_valid_i && !pipeline_stall_i) begin
            instruction_completed_count <= instruction_completed_count + 64'h1;
        end
        
        // === BPU Request Statistics ===
        if (bpu_req_i) begin
            bpu_requests_o <= bpu_requests_o + 64'h1;
            
            if (bpu_pred_valid_i) begin
                bpu_valid_predictions_o <= bpu_valid_predictions_o + 64'h1;
            end
            
            if (branch_hit_i) begin
                bht_hits_o <= bht_hits_o + 64'h1;
            end else begin
                bht_misses_o <= bht_misses_o + 64'h1;
            end
        end
        
        // === BHT Update Statistics ===
        if (bht_write_enable_i) begin
            bht_updates_o <= bht_updates_o + 64'h1;
        end
        
        // === Branch Instruction Type Counting ===
        if (exe_valid_i && is_branch_instruction) begin
            total_branches_o <= total_branches_o + 64'h1;
            
            if (exe_is_jal_i) begin
                jal_count_o <= jal_count_o + 64'h1;
            end else if (exe_is_jalr_i) begin
                jalr_count_o <= jalr_count_o + 64'h1;
            end else if (exe_is_cond_branch_i) begin
                cond_branch_count_o <= cond_branch_count_o + 64'h1;
            end
        end
        
        // === Branch Direction Statistics ===
        if (exe_valid_i && exe_is_branch_i) begin
            if (branch_taken_i) begin
                branches_taken_o <= branches_taken_o + 64'h1;
            end else begin
                branches_not_taken_o <= branches_not_taken_o + 64'h1;
            end
        end
        
        // === Prediction Accuracy Analysis ===
        // Use PC-matched prediction for more accurate analysis
        if (exe_valid_i && exe_is_branch_i) begin
            if (!branch_misprediction_i) begin
                correct_predictions_o <= correct_predictions_o + 64'h1;
            end else begin
                incorrect_predictions_o <= incorrect_predictions_o + 64'h1;
                
                // Use PC-matched prediction if available, fallback to pipeline tracking
                if (exe_pred_match_found) begin
                    // PC-matched analysis (more accurate)
                    if (exe_pred_decision && !branch_taken_i) begin
                        // Predicted taken, actually not taken
                        false_positive_o <= false_positive_o + 64'h1;
                    end else if (!exe_pred_decision && branch_taken_i) begin
                        // Predicted not taken (or miss), actually taken
                        false_negative_o <= false_negative_o + 64'h1;
                    end else if (exe_pred_valid && exe_pred_decision == branch_taken_i && 
                                exe_pred_target != exe_branch_target_i) begin
                        // Correct direction, wrong target (only for valid predictions)
                        target_mispred_o <= target_mispred_o + 64'h1;
                    end
                end else begin
                    // Fallback to legacy pipeline tracking
                    if (prediction_decision_ff && !branch_taken_i) begin
                        // Predicted taken, actually not taken
                        false_positive_o <= false_positive_o + 64'h1;
                    end else if (!prediction_decision_ff && branch_taken_i) begin
                        // Predicted not taken (or miss), actually taken
                        false_negative_o <= false_negative_o + 64'h1;
                    end else if (branch_predicted_ff && prediction_decision_ff == branch_taken_i && 
                                predicted_target_ff != exe_branch_target_i) begin
                        // Correct direction, wrong target (only for valid predictions)
                        target_mispred_o <= target_mispred_o + 64'h1;
                    end
                end
            end
        end
        
        // === Penalty Cycle Counting ===
        // Only count penalty cycles when not stalled to avoid counting other bottlenecks
        if (penalty_counting && !pipeline_stall_i) begin
            mispred_penalty_cycles_o <= mispred_penalty_cycles_o + 64'h1;
        end
        
        if (flush_fetch_i || flush_decode_i) begin
            flush_cycles_o <= flush_cycles_o + 64'h1;
        end
        
        // === Pipeline Performance ===
        if (pipeline_stall_i) begin
            pipeline_stalls_o <= pipeline_stalls_o + 64'h1;
        end
        
        // === BHT Conflict Detection (Optional - Enable with BHT_ANALYSIS_ENABLE) ===
`ifdef BHT_ANALYSIS_ENABLE
        if (bht_conflict) begin
            bht_conflicts_o <= bht_conflicts_o + 64'h1;
        end
        
        // === BHT Utilization Tracking ===
        // Sample BHT utilization by tracking write addresses (use low 5 bits instead of % 32)
        if (bht_write_enable_i) begin
            bht_utilization_o[bht_write_addr_i[4:0]] <= 1'b1;
        end
`endif
    end
end

// =============================================================================
// Performance Metrics - Raw Numerator/Denominator (for software percentage calculation)
// =============================================================================

// Update raw counters for software percentage calculation
always @(posedge clk_i) begin
    if (rst_i || profiler_reset_i) begin
        prediction_accuracy_numerator_o <= 64'h0;
        prediction_accuracy_denominator_o <= 64'h0;
        bht_hit_rate_numerator_o <= 64'h0;
        bht_hit_rate_denominator_o <= 64'h0;
        avg_penalty_numerator_o <= 64'h0;
        avg_penalty_denominator_o <= 64'h0;
    end else if (profiler_enable_i) begin
        // Prediction accuracy: correct_predictions / total_predictions
        prediction_accuracy_numerator_o <= correct_predictions_o;
        prediction_accuracy_denominator_o <= correct_predictions_o + incorrect_predictions_o;
        
        // BHT hit rate: bht_hits / total_bpu_requests
        bht_hit_rate_numerator_o <= bht_hits_o;
        bht_hit_rate_denominator_o <= bht_hits_o + bht_misses_o;
        
        // Average penalty per misprediction: total_penalty_cycles / total_mispredictions
        avg_penalty_numerator_o <= mispred_penalty_cycles_o;
        avg_penalty_denominator_o <= incorrect_predictions_o;
        
        // CPI calculation: execution_cycles / completed_instructions
        cpi_numerator_o <= execution_cycle_count;
        cpi_denominator_o <= instruction_completed_count;
    end
end

// =============================================================================
// Debug Signals (mark for ILA)
// =============================================================================

(* mark_debug = "true" *) reg [63:0] total_branches_debug;
(* mark_debug = "true" *) reg [63:0] correct_predictions_debug;
(* mark_debug = "true" *) reg [63:0] incorrect_predictions_debug;
(* mark_debug = "true" *) reg [63:0] prediction_accuracy_numerator_debug;
(* mark_debug = "true" *) reg [63:0] prediction_accuracy_denominator_debug;
(* mark_debug = "true" *) reg [63:0] bht_hit_rate_numerator_debug;
(* mark_debug = "true" *) reg [63:0] bht_hit_rate_denominator_debug;
(* mark_debug = "true" *) reg [63:0] mispred_penalty_debug;
(* mark_debug = "true" *) reg [63:0] bht_hits_debug;
(* mark_debug = "true" *) reg [63:0] bht_misses_debug;
(* mark_debug = "true" *) reg        penalty_counting_debug;

// CPI Debug Signals for ILA
(* mark_debug = "true" *) reg [63:0] cpi_numerator_debug;
(* mark_debug = "true" *) reg [63:0] cpi_denominator_debug;
(* mark_debug = "true" *) reg [63:0] instruction_completed_debug;
(* mark_debug = "true" *) reg [63:0] execution_cycles_debug;

// PC Debug Signal for ILA Trigger (CoreMark completion detection)
(* mark_debug = "true" *) reg [XLEN-1:0] fetch_pc_debug;

always @(posedge clk_i) begin
    total_branches_debug <= total_branches_o;
    correct_predictions_debug <= correct_predictions_o;
    incorrect_predictions_debug <= incorrect_predictions_o;
    prediction_accuracy_numerator_debug <= prediction_accuracy_numerator_o;
    prediction_accuracy_denominator_debug <= prediction_accuracy_denominator_o;
    bht_hit_rate_numerator_debug <= bht_hit_rate_numerator_o;
    bht_hit_rate_denominator_debug <= bht_hit_rate_denominator_o;
    mispred_penalty_debug <= mispred_penalty_cycles_o;
    bht_hits_debug <= bht_hits_o;
    bht_misses_debug <= bht_misses_o;
    penalty_counting_debug <= penalty_counting;
    
    // CPI Debug Signals
    cpi_numerator_debug <= cpi_numerator_o;
    cpi_denominator_debug <= cpi_denominator_o;
    instruction_completed_debug <= instruction_completed_count;
    execution_cycles_debug <= execution_cycle_count;
    
    // PC Debug Signal for ILA Trigger
    fetch_pc_debug <= fetch_pc_i;
end

endmodule
