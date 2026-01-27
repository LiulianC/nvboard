TOPNAME = top
NXDC_FILES = constr/top.nxdc
INC_PATH ?=

VERILATOR = verilator

# -MMD：自动生成头文件依赖关系（.d 文件），方便增量编译。
# --build：让 Verilator 不仅生成代码，还直接调用底层编译器去构建（省去了手动 make 的步骤）。
# -cc：生成 C++ 格式代码。
# -O3：开启最高级别的编译优化，生成的仿真程序运行速度更快。
# --x-assign fast：优化未初始化的逻辑（赋初值），为了速度可能牺牲一点点对 X 态的精确模拟。
# --x-initial fast：优化寄存器初始化过程。
# --noassert：禁用断言。忽略 Verilog 代码中的 assert 语句，通常是为了性能。

VERILATOR_CFLAGS += -MMD --build -cc  \
				-O3 --x-assign fast --x-initial fast --noassert

BUILD_DIR = ./build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

default: $(BIN)

$(shell mkdir -p $(BUILD_DIR))

# constraint file    abspath 将路径转换为绝对路径。 保证编译过程非常稳定
SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)
$(SRC_AUTO_BIND): $(NXDC_FILES)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

# project source
VSRCS = $(shell find $(abspath ./vsrc) -name "*.v")
CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
CSRCS += $(SRC_AUTO_BIND)

# rules for NVBoard
include $(NVBOARD_HOME)/scripts/nvboard.mk

# rules for verilator    addprefix 给列表中的每个元素前面加上指定的前缀。
# 让编译器去 include/ 文件夹里找头文件，你必须加参数 -Iinclude/。注意 -I 和路径之间没有空格
# 执行前 (INC_PATH 的内容）：src/include common
# 执行后 (INCFLAGS 的内容）：-Isrc/include -Icommon
INCFLAGS = $(addprefix -I, $(INC_PATH)) 

# 将上面生成的路径参数，追加到总的 C++ 编译标志（CXXFLAGS）中，并且定义了一个宏
# -D：这是 C++ 编译器的参数，意思是“Define a macro”（定义一个宏）
# -DTOP_NAME="\"V$(TOPNAME)\"" 定义 TOP_NAME 为 "VTOPNAME" 带双引号
CXXFLAGS += $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\""

CXXFLAGS += -g -O0

$(BIN): $(VSRCS) $(CSRCS) $(NVBOARD_ARCHIVE)
	@rm -rf $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

all: default

# @ (静默符号)
# $^ (自动变量)
# $(BIN) 指代最终生成的二进制可执行文件的路径
run: $(BIN)
	@$^
# 等效于运行编译好的文件 ./build/top

clean:
	rm -rf $(BUILD_DIR)


.PHONY: default all clean run


