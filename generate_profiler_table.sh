#!/bin/bash
# =============================================================================
# Script: generate_profiler_table.sh
# Purpose: 從 RISC-V ELF 檔案自動生成 profiler 函式位址表（用於 FPGA 上板）
# Author: HW1 Student
# Date: Oct/06/2025
# =============================================================================
# 
# 這個腳本會：
# 1. 從 CoreMark RISC-V ELF 檔案中提取函式位址
# 2. 生成 profiler_func_table.vh 供 Verilog 模組使用
# 3. 計算函式的結束位址（下一個函式的起始位址）
# 4. 使用半開區間 [START, END) 以精確匹配函式範圍
#
# 使用方法：
#   ./generate_profiler_table.sh
#
# =============================================================================

echo "======================================================================"
echo "  RISC-V Profiler Function Table Generator"
echo "  生成 profiler_func_table.vh 供 FPGA 硬體 Profiler 使用"
echo "======================================================================"
echo ""

# 設定路徑
COREMARK_DIR="/home/johnny/MPD/aquila_sw/CoreMark"
OUTPUT_VH="/home/johnny/MPD/aquila_build/src/core_rtl/profiler_func_table.vh"
OUTPUT_TXT="/home/johnny/MPD/profiler_function_addresses.txt"

# 檢查 CoreMark 目錄
if [ ! -d "$COREMARK_DIR" ]; then
    echo "錯誤: CoreMark 目錄不存在: $COREMARK_DIR"
    exit 1
fi

cd "$COREMARK_DIR"

# 檢查 ELF 檔案
ELF_FILE=""
if [ -f "coremark.elf" ]; then
    ELF_FILE="coremark.elf"
elif [ -f "coremark" ]; then
    ELF_FILE="coremark"
else
    echo "錯誤: 找不到 CoreMark ELF 檔案!"
    echo "請先編譯 CoreMark: make"
    exit 1
fi

echo "使用 ELF 檔案: $ELF_FILE"
echo ""

# 檢查 RISC-V 工具鏈
if ! command -v riscv32-unknown-elf-nm &> /dev/null; then
    echo "錯誤: riscv32-unknown-elf-nm 未找到!"
    echo "請確保 RISC-V 工具鏈已安裝並在 PATH 中。"
    exit 1
fi

# Top 5 熱點函式（來自 gprof 分析）
FUNC_NAMES=(
    "core_list_reverse"
    "core_list_find"
    "matrix_mul_matrix_bitextract"
    "core_state_transition"
    "crcu8"
)

FUNC_PERCENT=(
    "26.22%"
    "25.36%"
    "10.17%"
    "7.88%"
    "6.88%"
)

echo "提取函式位址..."
echo ""

# 獲取排序後的符號表
SYMBOL_TABLE=$(riscv32-unknown-elf-nm -n "$ELF_FILE")

# 儲存函式位址
declare -a FUNC_START_ADDRS
declare -a FUNC_END_ADDRS

for i in {0..4}; do
    func="${FUNC_NAMES[$i]}"
    
    # 獲取函式起始位址
    ADDR=$(echo "$SYMBOL_TABLE" | grep -w "T $func" | awk '{print $1}')
    
    if [ -z "$ADDR" ]; then
        echo "警告: 函式 $func 未在符號表中找到"
        FUNC_START_ADDRS[$i]="00000000"
        FUNC_END_ADDRS[$i]="00000000"
        continue
    fi
    
    # 轉換為十進制
    ADDR_DEC=$((16#$ADDR))
    
    # 找到下一個函式位址來計算結束位址
    # 使用半開區間 [START, END)，所以 END = 下一個函式的 START
    NEXT_ADDR=$(echo "$SYMBOL_TABLE" | awk -v addr=$ADDR_DEC '
        $1 ~ /^[0-9a-f]+$/ && $2 == "T" {
            curr = strtonum("0x" $1)
            if (curr > addr && (next == 0 || curr < next)) {
                next = curr
            }
        }
        END { if (next > 0) printf("%08x", next) }
    ')
    
    if [ -n "$NEXT_ADDR" ]; then
        END_DEC=$((16#$NEXT_ADDR))
    else
        # 如果找不到下一個函式，假設大小為 256 bytes
        END_DEC=$((ADDR_DEC + 256))
    fi
    
    FUNC_START_ADDRS[$i]=$(printf "%08x" $ADDR_DEC)
    FUNC_END_ADDRS[$i]=$(printf "%08x" $END_DEC)
    
    SIZE=$((END_DEC - ADDR_DEC))
    echo "Function $i: $func"
    echo "  START: 0x${FUNC_START_ADDRS[$i]}"
    echo "  END:   0x${FUNC_END_ADDRS[$i]} (不包含，半開區間)"
    echo "  SIZE:  $SIZE bytes (0x$(printf "%x" $SIZE))"
    echo ""
done

# =============================================================================
# 生成 Verilog Header 檔案 (.vh)
# =============================================================================

cat > "$OUTPUT_VH" << 'HEADER_START'
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
HEADER_START

# 加入生成資訊
echo "//  生成時間: $(date)" >> "$OUTPUT_VH"
echo "//  ELF 檔案: $ELF_FILE" >> "$OUTPUT_VH"
echo "//  " >> "$OUTPUT_VH"
echo "//  使用方式: 在 Verilog 模組中使用 \`include \"profiler_func_table.vh\"" >> "$OUTPUT_VH"
echo "// " >> "$OUTPUT_VH"
echo "//  注意事項:" >> "$OUTPUT_VH"
echo "//  - 位址範圍使用半開區間 [START, END)" >> "$OUTPUT_VH"
echo "//  - 函式判斷條件: (pc >= START) && (pc < END)" >> "$OUTPUT_VH"
echo "//  - 每次重新編譯 CoreMark 後需重新生成此檔案" >> "$OUTPUT_VH"
echo "// =============================================================================" >> "$OUTPUT_VH"
echo "" >> "$OUTPUT_VH"

# 生成 Top 5 函式的位址定義
for i in {0..4}; do
    func="${FUNC_NAMES[$i]}"
    percent="${FUNC_PERCENT[$i]}"
    start="${FUNC_START_ADDRS[$i]}"
    end="${FUNC_END_ADDRS[$i]}"
    
    echo "// Function $i: $func (熱點佔比: $percent)" >> "$OUTPUT_VH"
    echo "\`define FUNC${i}_NAME \"$func\"" >> "$OUTPUT_VH"
    echo "\`define FUNC${i}_START 32'h${start}" >> "$OUTPUT_VH"
    echo "\`define FUNC${i}_END   32'h${end}  // 半開區間，不包含此位址" >> "$OUTPUT_VH"
    echo "" >> "$OUTPUT_VH"
done

echo "// =============================================================================" >> "$OUTPUT_VH"
echo "// 函式列表摘要" >> "$OUTPUT_VH"
echo "// =============================================================================" >> "$OUTPUT_VH"
echo "//" >> "$OUTPUT_VH"
for i in {0..4}; do
    func="${FUNC_NAMES[$i]}"
    percent="${FUNC_PERCENT[$i]}"
    start="${FUNC_START_ADDRS[$i]}"
    end="${FUNC_END_ADDRS[$i]}"
    size=$((16#$end - 16#$start))
    
    printf "//  FUNC%d: %-35s [0x%s, 0x%s) %5d bytes  %s\n" \
        $i "$func" "$start" "$end" $size "$percent" >> "$OUTPUT_VH"
done
echo "//" >> "$OUTPUT_VH"
echo "// =============================================================================" >> "$OUTPUT_VH"

echo ""
echo "======================================================================"
echo "✓ 成功生成 profiler_func_table.vh"
echo ""
echo "輸出檔案:"
echo "  - $OUTPUT_VH"
echo ""
echo "下一步："
echo "  1. 檢查生成的位址範圍"
echo "  2. 確保 profiler.v 中有 \`include \"profiler_func_table.vh\""
echo "  3. 綜合並燒錄到 FPGA"
echo "  4. 使用 ILA 觀察 profiler 計數器"
echo ""
echo "注意："
echo "  - 每次重新編譯 CoreMark 後都需要重新執行此腳本"
echo "  - 位址範圍使用半開區間 [START, END) 確保準確性"
echo "======================================================================"



