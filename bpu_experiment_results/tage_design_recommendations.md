# TAGE Branch Predictor Design Recommendations

Based on BPU performance analysis experiments with CoreMark benchmark.

Analysis Date: 2025-10-21 14:21

## Key Findings

**Base Table Size**: 256 entries (from xlarge configuration)
  - Performance improvement: 10.00%
  - Diminishing returns observed beyond 256 entries

**Global History Requirements**:
  - Highest misprediction function: core_state_transition (17.9%)
  - Recommend 3-4 tagged tables with history lengths: 2, 4, 8, 16 bits
  - Focus on loop and recursive patterns in hotspot functions

**Table Organization**:
  - Baseline BHT hit rate: 80.0%
  - Small table shows 21.6% hit rate degradation
  - Recommend separate tables to reduce conflicts

**TAGE Implementation Priority**:
  - Branch prediction provides 45.0% performance benefit
  - Implement useful counters for provider selection
  - Consider 8-bit tags for tagged tables
  - Use geometric history lengths: 2^1, 2^2, 2^3, 2^4

## Proposed TAGE Architecture

```
Base Table: 64 entries, 2-bit counters
Tagged Table 1: 64 entries, 8-bit tags, 2-bit history
Tagged Table 2: 64 entries, 8-bit tags, 4-bit history
Tagged Table 3: 64 entries, 8-bit tags, 8-bit history
Tagged Table 4: 64 entries, 8-bit tags, 16-bit history
Global History Register: 16 bits
Useful Counters: 2-bit per tagged entry
```

## Implementation Notes

- Use folded history for longer history lengths
- Implement provider component selection logic
- Consider resource constraints on FPGA
- Validate with additional benchmarks beyond CoreMark
