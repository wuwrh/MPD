# =============================================================================
# BPU Profiler ILA Configuration TCL Script
# =============================================================================
# This script sets up Integrated Logic Analyzer (ILA) to monitor BPU profiler
# signals for branch prediction behavior analysis in Aquila processor.
#
# Usage in Vivado TCL console:
#   source setup_bpu_profiler_ila.tcl
#   setup_bpu_profiler_ila
# =============================================================================

proc setup_bpu_profiler_ila {} {
    puts "Setting up BPU Profiler ILA configuration..."
    
    # ==========================================================================
    # ILA Core Configuration
    # ==========================================================================
    
    # Create ILA core for BPU profiler monitoring
    create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name bpu_profiler_ila
    
    # Configure ILA properties
    set_property -dict [list \
        CONFIG.C_PROBE0_WIDTH {64} \
        CONFIG.C_PROBE1_WIDTH {64} \
        CONFIG.C_PROBE2_WIDTH {64} \
        CONFIG.C_PROBE3_WIDTH {64} \
        CONFIG.C_PROBE4_WIDTH {64} \
        CONFIG.C_PROBE5_WIDTH {64} \
        CONFIG.C_PROBE6_WIDTH {64} \
        CONFIG.C_PROBE7_WIDTH {64} \
        CONFIG.C_PROBE8_WIDTH {32} \
        CONFIG.C_PROBE9_WIDTH {32} \
        CONFIG.C_PROBE10_WIDTH {32} \
        CONFIG.C_PROBE11_WIDTH {32} \
        CONFIG.C_PROBE12_WIDTH {1} \
        CONFIG.C_PROBE13_WIDTH {1} \
        CONFIG.C_PROBE14_WIDTH {1} \
        CONFIG.C_NUM_OF_PROBES {15} \
        CONFIG.C_DATA_DEPTH {4096} \
        CONFIG.C_TRIGIN_EN {true} \
        CONFIG.C_TRIGOUT_EN {false} \
        CONFIG.ALL_PROBE_SAME_MU {true} \
        CONFIG.ALL_PROBE_SAME_MU_CNT {4} \
    ] [get_ips bpu_profiler_ila]
    
    puts "ILA IP core created and configured."
}

proc connect_bpu_profiler_signals {} {
    puts "Connecting BPU profiler signals to ILA..."
    
    # ==========================================================================
    # Signal Connection Instructions
    # ==========================================================================
    
    puts "Please connect the following signals to ILA probes manually in Vivado:"
    puts ""
    
    # Core performance metrics (Probe 0-7)
    puts "=== Core Performance Metrics ==="
    puts "probe0[63:0]  <- core_top_inst/bpu_prof_total_branches"
    puts "probe1[63:0]  <- core_top_inst/bpu_prof_correct_predictions" 
    puts "probe2[63:0]  <- core_top_inst/bpu_prof_incorrect_predictions"
    puts "probe3[63:0]  <- core_top_inst/bpu_prof_bht_hits"
    puts "probe4[63:0]  <- core_top_inst/bpu_prof_bht_misses"
    puts "probe5[63:0]  <- core_top_inst/bpu_prof_mispred_penalty_cycles"
    puts "probe6[63:0]  <- core_top_inst/bpu_prof_total_cycles"
    puts "probe7[63:0]  <- core_top_inst/bpu_prof_bpu_requests"
    
    # Real-time metrics (Probe 8-11)  
    puts ""
    puts "=== Real-time Performance Indicators ==="
    puts "probe8[31:0]  <- core_top_inst/bpu_prof_prediction_accuracy_percent"
    puts "probe9[31:0]  <- core_top_inst/bpu_prof_bht_hit_rate_percent"
    puts "probe10[31:0] <- core_top_inst/bpu_prof_avg_penalty_per_mispred"
    puts "probe11[31:0] <- core_top_inst/bpu_prof_bht_utilization"
    
    # Control signals (Probe 12-14)
    puts ""
    puts "=== Control and Status Signals ==="
    puts "probe12[0]    <- core_top_inst/BPU_Profiler/branch_misprediction_i"  
    puts "probe13[0]    <- core_top_inst/BPU_Profiler/bpu_req_i"
    puts "probe14[0]    <- core_top_inst/BPU_Profiler/branch_hit_i"
    
    puts ""
}

proc setup_ila_triggers {} {
    puts "Setting up recommended ILA trigger conditions..."
    
    puts ""
    puts "=== Recommended Trigger Configurations ==="
    puts ""
    
    puts "1. **Low Prediction Accuracy Trigger**"
    puts "   Condition: probe8 < 32'd85  // Accuracy < 85%"
    puts "   Use: Capture when prediction performance degrades"
    puts ""
    
    puts "2. **High Misprediction Event Trigger**"
    puts "   Condition: probe2 > 64'd1000  // More than 1000 mispredictions"
    puts "   Use: Analyze periods with many mispredictions"
    puts ""
    
    puts "3. **BHT Miss Rate High Trigger**"
    puts "   Condition: probe9 < 32'd70   // BHT hit rate < 70%"
    puts "   Use: Debug BHT utilization issues"
    puts ""
    
    puts "4. **Misprediction Event Trigger**"
    puts "   Condition: probe12 == 1'b1   // Branch misprediction detected"
    puts "   Use: Capture exact misprediction moments"
    puts ""
    
    puts "5. **Performance Analysis Trigger**"
    puts "   Condition: probe0 > 64'd10000 && probe8 < 32'd90"
    puts "   Use: Analyze after sufficient branches with suboptimal performance"
    puts ""
}

proc generate_analysis_dashboard {} {
    puts "Creating analysis dashboard template..."
    
    puts ""
    puts "=== BPU Performance Analysis Dashboard ==="
    puts ""
    
    puts "**Key Performance Indicators (KPIs):**"
    puts "- Prediction Accuracy: (correct_predictions / total_branches) × 100%"
    puts "- BHT Hit Rate: (bht_hits / bpu_requests) × 100%"
    puts "- Misprediction Rate: (incorrect_predictions / total_branches) × 100%"
    puts "- Performance Impact: (mispred_penalty_cycles / total_cycles) × 100%"
    puts ""
    
    puts "**Branch Type Distribution:**"
    puts "- JAL Instructions: bpu_prof_jal_count"
    puts "- JALR Instructions: bpu_prof_jalr_count"  
    puts "- Conditional Branches: bpu_prof_cond_branch_count"
    puts ""
    
    puts "**Misprediction Analysis:**"
    puts "- False Positives: bpu_prof_false_positive (predicted taken, actually not taken)"
    puts "- False Negatives: bpu_prof_false_negative (predicted not taken, actually taken)"
    puts "- Target Errors: bpu_prof_target_mispred (correct direction, wrong target)"
    puts ""
    
    puts "**System Impact:**"
    puts "- Pipeline Stalls: bpu_prof_pipeline_stalls"
    puts "- Flush Cycles: bpu_prof_flush_cycles"
    puts "- Average Penalty per Misprediction: bpu_prof_avg_penalty_per_mispred"
    puts ""
}

proc create_bpu_analysis_constraints {} {
    puts "Creating timing and placement constraints for BPU profiler..."
    
    # Create constraints file
    set constraints_file "bpu_profiler_constraints.xdc"
    set file_handle [open $constraints_file w]
    
    puts $file_handle "# ============================================================================="
    puts $file_handle "# BPU Profiler Timing and Placement Constraints"
    puts $file_handle "# ============================================================================="
    puts $file_handle ""
    
    puts $file_handle "# BPU Profiler clock constraints"
    puts $file_handle "# Assume BPU profiler runs at same frequency as core"
    puts $file_handle "set_property CLOCK_DEDICATED_ROUTE BACKBONE \[get_nets clk_i\]"
    puts $file_handle ""
    
    puts $file_handle "# Keep BPU profiler debug signals for ILA"
    puts $file_handle "set_property KEEP_HIERARCHY TRUE \[get_cells core_top_inst/BPU_Profiler\]"
    puts $file_handle ""
    
    puts $file_handle "# Mark BPU profiler debug signals"
    puts $file_handle "set_property MARK_DEBUG TRUE \[get_nets {core_top_inst/bpu_prof_*}\]"
    puts $file_handle ""
    
    puts $file_handle "# ILA clock constraint"
    puts $file_handle "create_clock -period 10.000 -name ila_clk \[get_pins bpu_profiler_ila_inst/clk\]"
    puts $file_handle ""
    
    close $file_handle
    puts "Constraints written to: $constraints_file"
}

proc show_performance_equations {} {
    puts ""
    puts "=== BPU Performance Analysis Equations ==="
    puts ""
    
    puts "**Basic Metrics:**"
    puts "Prediction Accuracy (%) = (Correct Predictions / Total Branches) × 100"
    puts "Misprediction Rate (%)  = (Incorrect Predictions / Total Branches) × 100"  
    puts "BHT Hit Rate (%)        = (BHT Hits / BPU Requests) × 100"
    puts ""
    
    puts "**Performance Impact:**"
    puts "Penalty Overhead (%)    = (Misprediction Penalty Cycles / Total Cycles) × 100"
    puts "Avg Penalty per Miss    = Misprediction Penalty Cycles / Incorrect Predictions"
    puts "Potential Improvement   = Penalty Overhead % (if all mispredictions eliminated)"
    puts ""
    
    puts "**Branch Behavior Analysis:**"
    puts "Branch Taken Rate (%)   = (Branches Taken / (Branches Taken + Branches Not Taken)) × 100"
    puts "JAL Ratio (%)           = (JAL Count / Total Branches) × 100"
    puts "JALR Ratio (%)          = (JALR Count / Total Branches) × 100"
    puts "Conditional Ratio (%)   = (Conditional Branch Count / Total Branches) × 100"
    puts ""
    
    puts "**Error Analysis:**"
    puts "False Positive Rate (%) = (False Positives / Incorrect Predictions) × 100"
    puts "False Negative Rate (%) = (False Negatives / Incorrect Predictions) × 100"  
    puts "Target Error Rate (%)   = (Target Mispredictions / Incorrect Predictions) × 100"
    puts ""
}

# =============================================================================
# Main execution function
# =============================================================================

proc run_bpu_profiler_setup {} {
    puts "======================================="
    puts "BPU Profiler ILA Setup Script"
    puts "======================================="
    
    setup_bpu_profiler_ila
    connect_bpu_profiler_signals  
    setup_ila_triggers
    generate_analysis_dashboard
    create_bpu_analysis_constraints
    show_performance_equations
    
    puts ""
    puts "======================================="
    puts "BPU Profiler Setup Complete!"
    puts "======================================="
    puts ""
    puts "Next steps:"
    puts "1. Run synthesis and implementation"
    puts "2. Connect ILA probe signals as shown above"
    puts "3. Configure triggers based on analysis needs"
    puts "4. Program FPGA and start data collection"
    puts "5. Use analysis equations for performance evaluation"
    puts ""
}

# Auto-run the setup when script is sourced
puts "BPU Profiler ILA setup script loaded."
puts "Run 'run_bpu_profiler_setup' to execute complete setup."
