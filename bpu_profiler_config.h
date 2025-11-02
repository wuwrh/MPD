// =============================================================================
// BPU Profiler Configuration Header
// =============================================================================
// This file contains configuration options for the BPU profiler.
// Uncomment the desired features to enable them during synthesis.
// =============================================================================

// =============================================================================
// BHT Analysis Features (Optional)
// =============================================================================
// Enable BHT conflict detection and utilization tracking
// This adds extra hardware overhead for detailed BHT analysis
// Uncomment the line below to enable:
// `define BHT_ANALYSIS_ENABLE

// =============================================================================
// Usage Instructions:
// =============================================================================
// 1. To enable BHT analysis features:
//    - Uncomment `define BHT_ANALYSIS_ENABLE
//    - Include this file in your synthesis script or add to compiler flags
//
// 2. To disable BHT analysis features (default):
//    - Keep the define commented out
//    - The profiler will work without BHT-specific analysis
//
// 3. Compilation example:
//    - With BHT analysis: +define+BHT_ANALYSIS_ENABLE
//    - Without BHT analysis: (no additional flags needed)
//
// =============================================================================
// Features controlled by BHT_ANALYSIS_ENABLE:
// =============================================================================
// - bht_conflicts_o: Tracks BHT index conflicts
// - bht_utilization_o: Samples BHT utilization bitmap
// - Related internal logic for conflict detection
// =============================================================================
