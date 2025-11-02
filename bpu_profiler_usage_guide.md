# BPU Profiler 使用指南

## 概述

BPU Profiler 是為 Aquila 處理器設計的分支預測單元 (Branch Prediction Unit, BPU) 行為分析工具。它能夠收集分支預測的關鍵統計數據，幫助分析和優化 TAGE 分支預測器的性能。

## 功能特色

### 1. 分支指令分類統計
- **JAL 指令計數** (`jal_count_o`): 無條件跳躍指令
- **JALR 指令計數** (`jalr_count_o`): 間接跳躍指令  
- **條件分支計數** (`cond_branch_count_o`): 條件分支指令
- **總分支指令數** (`total_branches_o`): 所有分支指令的總計

### 2. 分支走向分析
- **實際執行分支** (`branches_taken_o`): 實際被執行的分支數量
- **未執行分支** (`branches_not_taken_o`): 未被執行的分支數量

### 3. BPU 供需與 BHT 分析
- **BPU 請求數** (`bpu_requests_o`): BPU 總查詢次數
- **有效預測數** (`bpu_valid_predictions_o`): BPU 提供有效預測的次數
- **BHT 命中數** (`bht_hits_o`): 分支歷史表命中次數
- **BHT 未命中數** (`bht_misses_o`): 分支歷史表未命中次數
- **BHT 更新數** (`bht_updates_o`): 分支歷史表更新次數
- **BHT 衝突數** (`bht_conflicts_o`): 同一索引連續存取的衝突次數

### 4. 預測正確率分析
- **正確預測數** (`correct_predictions_o`): 正確預測的分支數量
- **錯誤預測數** (`incorrect_predictions_o`): 錯誤預測的分支數量
- **假正例** (`false_positive_o`): 預測執行但實際未執行的分支
- **假負例** (`false_negative_o`): 預測未執行但實際執行的分支
- **目標錯誤** (`target_mispred_o`): 方向正確但目標地址錯誤的預測

### 5. Misprediction 懲罰週期
- **錯誤預測懲罰週期** (`mispred_penalty_cycles_o`): 因錯誤預測造成的懲罰週期總數
- **管線刷新週期** (`flush_cycles_o`): 管線刷新的週期數
- **每次錯誤預測平均懲罰** (`avg_penalty_per_mispred_o`): 平均每次錯誤預測的懲罰週期

### 6. 全域管線統計
- **管線停滯週期** (`pipeline_stalls_o`): 管線停滯的總週期數
- **總執行週期** (`total_cycles_o`): 總執行週期數

### 7. 即時性能指標
- **預測正確率百分比** (`prediction_accuracy_percent_o`): 即時預測正確率 (0-100%)
- **BHT 命中率百分比** (`bht_hit_rate_percent_o`): 即時 BHT 命中率 (0-100%)

## 使用方式

### 1. 硬體集成
BPU Profiler 已經集成到 `core_top.v` 中，會自動開始收集統計數據。所有統計信號都標記為 `(* mark_debug = "true" *)` 以便在 ILA (Integrated Logic Analyzer) 中觀察。

### 2. ILA 配置建議
在 Vivado 中配置 ILA 時，建議監控以下關鍵信號：
```tcl
# 基本性能指標
bpu_prof_prediction_accuracy_percent
bpu_prof_bht_hit_rate_percent  
bpu_prof_total_branches
bpu_prof_correct_predictions
bpu_prof_incorrect_predictions

# 詳細錯誤分析
bpu_prof_false_positive
bpu_prof_false_negative
bpu_prof_target_mispred

# 性能影響
bpu_prof_mispred_penalty_cycles
bpu_prof_avg_penalty_per_mispred
```

### 3. 觸發條件設置
建議使用以下觸發條件來捕獲有意義的數據：
```tcl
# 當預測正確率低於某個閾值時觸發
bpu_prof_prediction_accuracy_percent < 85

# 當錯誤預測數量達到一定數量時觸發  
bpu_prof_incorrect_predictions > 1000

# 當 BHT 命中率過低時觸發
bpu_prof_bht_hit_rate_percent < 70
```

## 性能分析範例

### 範例 1: 基本預測性能分析
```verilog
// 假設在 CoreMark 運行 100,000 週期後觀察到以下數值：
總分支指令數: 15,000
正確預測數: 12,750  
錯誤預測數: 2,250
BHT 命中數: 13,500
BHT 未命中數: 1,500

// 計算性能指標：
預測正確率 = 12,750 / 15,000 = 85%
BHT 命中率 = 13,500 / 15,000 = 90%
錯誤預測率 = 2,250 / 15,000 = 15%
```

### 範例 2: 錯誤類型分析
```verilog
// 錯誤預測細分：
假正例 (預測執行，實際未執行): 800
假負例 (預測未執行，實際執行): 1,200  
目標錯誤 (方向正確，目標錯誤): 250

// 分析結果：
假負例較多，表示預測器過於保守
需要調整 BPU 的閾值或改善全域歷史記錄
```

### 範例 3: 性能影響評估
```verilog
// 性能影響分析：
錯誤預測懲罰週期: 4,500
總執行週期: 100,000
平均每次錯誤預測懲罰: 2 週期

// 性能影響：
懲罰週期佔比 = 4,500 / 100,000 = 4.5%
如果消除所有錯誤預測，可提升性能約 4.7%
```

## TAGE 預測器設計指導

基於 profiler 統計數據，可以為 TAGE 預測器設計提供以下指導：

### 1. 表格大小決定
- 如果 BHT 命中率偏低，考慮增加 BHT 表格大小
- 如果 BHT 衝突頻繁，需要更好的索引函數或更大的表格

### 2. 歷史長度優化
- 假正例較多：縮短歷史長度，降低過擬合
- 假負例較多：延長歷史長度，增加預測能力

### 3. 預測器層級配置
- 根據不同類型分支的錯誤率，調整 TAGE 不同層級的權重
- JAL/JALR 錯誤率較高時，考慮專用的預測表格

### 4. 替換策略優化
- 監控 BHT 更新頻率，調整有用性計數器的更新策略
- 根據衝突統計，優化表格項目的替換算法

## 除錯建議

### 常見問題診斷
1. **預測正確率異常低 (<70%)**
   - 檢查 BPU 時序是否正確
   - 確認分支指令分類是否準確
   - 驗證執行階段的實際分支結果

2. **BHT 命中率過低 (<60%)**  
   - 檢查 BHT 索引計算是否正確
   - 確認 BHT 大小是否適當
   - 檢視 BHT 衝突統計

3. **錯誤預測懲罰過高**
   - 檢查管線刷新邏輯
   - 確認懲罰週期計算是否準確
   - 評估是否需要更快的錯誤預測恢復機制

## 進階分析

### 動態行為分析
利用 ILA 的時間軸功能，可以分析：
- 分支預測準確率的時間變化
- 不同程式階段的預測行為差異
- 迴圈和函數調用的預測模式

### 比較分析
通過開關不同的預測器配置，比較：
- Bimodal vs TAGE 的性能差異
- 不同 BHT 大小的影響
- 不同歷史長度的效果

這個 profiler 為 TAGE 分支預測器的設計和優化提供了全面的數據支持，幫助您實現更高效的分支預測性能。
