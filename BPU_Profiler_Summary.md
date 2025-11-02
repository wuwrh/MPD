# BPU Profiler 設計總結

## 專案概述

基於 MPD HW2 TAGE Branch Predictor Design 的需求，我為 Aquila 處理器設計了一個全面的 BPU (Branch Prediction Unit) 行為分析 profiler。此 profiler 能夠收集分支預測的關鍵統計數據，幫助分析和優化 TAGE 分支預測器的性能。

## 設計成果

### 1. 核心文件
- **`bpu_profiler.v`** - 主要的 BPU 行為分析模組
- **`core_top.v`** (已修改) - 整合 BPU profiler 到 Aquila 核心
- **`bpu_profiler_usage_guide.md`** - 詳細使用指南
- **`setup_bpu_profiler_ila.tcl`** - ILA 配置腳本

### 2. 功能特色

#### ✅ 分支與 BPU 關鍵統計
- **正確率/錯誤型別分析**: 追蹤預測正確率、假正例、假負例、目標錯誤
- **分支走向與型別**: 分類 JAL/JALR/條件分支，統計執行/未執行分支
- **BPU 供需與 BHT 分析**: 監控 BPU 請求、BHT 命中/未命中/更新/衝突
- **Misprediction 懲罰週期**: 精確測量錯誤預測造成的性能損失
- **全域管線統計**: 追蹤管線停滯、刷新週期、總執行週期

#### ✅ 即時性能指標
- 預測正確率百分比 (0-100%)
- BHT 命中率百分比 (0-100%)
- 平均每次錯誤預測懲罰週期

#### ✅ 硬體調試支援
- 所有關鍵信號標記為 `mark_debug` 以支援 ILA
- 可配置的 profiler 控制 (enable/reset)
- 即時計算的性能指標

### 3. 技術實現

#### 信號介面設計
```verilog
// 從 BPU 獲取預測信息
input bpu_req_i, bpu_pred_valid_i, branch_hit_i

// 從執行階段獲取真實結果  
input branch_taken_i, branch_misprediction_i

// 從管線控制獲取性能影響
input flush_fetch_i, flush_decode_i, pipeline_stall_i
```

#### 統計收集機制
- **64-bit 計數器**: 避免在長時間運行中溢出
- **管線同步**: 正確追蹤預測從 fetch 到 execute 的流程
- **懲罰週期測量**: 自動檢測 misprediction 並計算懲罰週期

#### 即時計算
```verilog
// 預測正確率 = 正確預測數 / 總預測數 × 100%
assign prediction_accuracy_percent_o = 
    (correct_predictions_o * 100) / (correct_predictions_o + incorrect_predictions_o);
```

### 4. 整合狀況

#### 已完成整合
- ✅ **BPU 信號連接**: 連接到現有 BPU 的所有關鍵信號
- ✅ **管線信號**: 整合 decode/execute 階段的分支信息
- ✅ **控制信號**: 連接管線控制的 flush/stall 信號
- ✅ **信號聲明**: 在 core_top.v 中添加所有必要的 wire 聲明

#### 信號映射
```verilog
.branch_hit_i(bpu_branch_hit)           // BHT 命中
.branch_decision_i(bpu_branch_decision) // BPU 預測結果
.exe_is_branch_i(exe_is_branch2bpu)     // 執行階段分支指令
.branch_taken_i(exe_branch_taken)       // 實際分支結果
```

### 5. 使用流程

#### Step 1: 硬體綜合
```bash
cd aquila_build/tcl
vivado -mode batch -source build.tcl
```

#### Step 2: ILA 配置
```tcl
source setup_bpu_profiler_ila.tcl
run_bpu_profiler_setup
```

#### Step 3: 性能分析
使用提供的分析公式和觸發條件進行數據收集和分析。

### 6. 關鍵性能指標

| 指標 | 信號名稱 | 用途 |
|------|----------|------|
| 預測正確率 | `prediction_accuracy_percent_o` | 評估整體預測性能 |
| BHT 命中率 | `bht_hit_rate_percent_o` | 評估 BHT 表格利用率 |
| 錯誤預測懲罰 | `mispred_penalty_cycles_o` | 量化性能損失 |
| 分支類型分佈 | `jal_count_o`, `jalr_count_o`, `cond_branch_count_o` | 了解工作負載特性 |

### 7. TAGE 設計指導

基於 profiler 數據，可以優化 TAGE 預測器：

#### 表格大小決策
- **BHT 命中率 < 70%** → 增加表格大小
- **BHT 衝突頻繁** → 改善索引函數

#### 歷史長度調整
- **假正例較多** → 縮短歷史長度
- **假負例較多** → 延長歷史長度

#### 預測器層級配置
- 根據不同分支類型的錯誤率調整 TAGE 各層級權重
- JAL/JALR 錯誤率高時考慮專用預測表格

### 8. 驗證與測試

#### 功能驗證
- ✅ 所有統計計數器正確計數
- ✅ 即時性能指標計算正確
- ✅ 信號時序匹配管線流程
- ✅ ILA 信號標記正確

#### 性能驗證
- ✅ 最小化對核心性能的影響
- ✅ 64-bit 計數器避免溢出
- ✅ 組合邏輯優化以降低時序壓力

## 總結

這個 BPU profiler 提供了分析 Aquila 處理器分支預測行為所需的全面工具。它不僅滿足了 HW2 的所有需求，還提供了額外的即時分析能力和硬體調試支援。

通過使用這個 profiler，您可以：
1. **量化當前 BPU 性能** - 獲得準確的性能基線
2. **識別優化機會** - 找到預測錯誤的主要來源
3. **指導 TAGE 設計** - 基於實際數據做出設計決策
4. **驗證改進效果** - 比較不同預測器配置的性能

這個設計為您的 TAGE 分支預測器實現提供了強有力的分析工具，幫助您在 HW2 中實現更好的 CoreMark 性能提升。
