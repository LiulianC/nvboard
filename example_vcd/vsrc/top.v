module top(
    input clk,
    input rst,
    input [4:0] btn,
    input [7:0] sw,
    input ps2_clk,
    input ps2_data,
    input uart_rx,
    output uart_tx,
    output [15:0] ledr,

// debug printf
    output processed_key_pressed_debug,
    output [7:0] key_count_debug,
    output [7:0] processed_key_code_debug,  // debug printf
    output [7:0] ascii_code_debug,          // debug printf

    output VGA_CLK,
    output VGA_HSYNC,
    output VGA_VSYNC,
    output VGA_BLANK_N,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,
    
    output [7:0] seg0,
    output [7:0] seg1,
    output [7:0] seg2,
    output [7:0] seg3,
    output [7:0] seg4,
    output [7:0] seg5,
    output [7:0] seg6,
    output [7:0] seg7
);

// ========== LED 模块 ==========
led my_led(
    .clk(clk),
    .rst(rst),
    .btn(btn),
    .sw(sw),
    .ledr(ledr)
);

// ========== VGA 模块 ==========
assign VGA_CLK = clk;

wire [9:0] h_addr;
wire [9:0] v_addr;
wire [23:0] vga_data;

vga_ctrl my_vga_ctrl(
    .pclk(clk),
    .reset(rst),
    .vga_data(vga_data),
    .h_addr(h_addr),
    .v_addr(v_addr),
    .hsync(VGA_HSYNC),
    .vsync(VGA_VSYNC),
    .valid(VGA_BLANK_N),
    .vga_r(VGA_R),
    .vga_g(VGA_G),
    .vga_b(VGA_B)
);

vmem my_vmem(
    .h_addr(h_addr),
    .v_addr(v_addr[8:0]),
    .vga_data(vga_data)
);

// ========== PS/2 键盘处理链路 ==========
// 1. PS/2接收模块：接收键盘11位数据并缓存到FIFO
wire [7:0] keyboard_scancode;
wire keyboard_ready;
wire keyboard_overflow;
wire keyboard_nextdata_n;

ps2_keyboard my_keyboard(
    .clk(clk),
    .clrn(rst),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),

    .data(keyboard_scancode),
    .ready(keyboard_ready),
    .nextdata_n(keyboard_nextdata_n), // 接收信号 不需要吧 有 ps2_data 就可以了
    .overflow(keyboard_overflow)  // fifo溢出信号
);

// 2. 扫描码处理模块：区分通码/断码
wire [7:0] processed_key_code;
wire processed_key_pressed;
wire processed_key_released;

scancode_processor my_scancode_processor(
    .clk(clk),
    .clrn(rst),
    .scancode(keyboard_scancode),
    .scancode_ready(keyboard_ready),
    .scancode_valid(1'b1),

    .nextdata_n(keyboard_nextdata_n),  //必要 发送信号 低电平有效一个周期，表示确认读取
    .key_code(processed_key_code),
    .key_pressed(processed_key_pressed),
    .key_released(processed_key_released), // 按键释放了 信号 有用
    .is_break_code()
);

// 3. 扫描码转ASCII模块：将扫描码转换为ASCII码
wire [7:0] ascii_code;
wire ascii_lookup_ready;

scancode_to_ascii my_scancode_to_ascii(
    .clk(clk),
    .clrn(rst),
    .scancode(processed_key_code),
    .lookup_valid(processed_key_pressed),
    .lookup_ready(ascii_lookup_ready),  // 已经转换成功 信号 
    .ascii_code(ascii_code)
);

// 4. 按键计数模块：统计按键总次数
wire [7:0] key_count;

key_counter my_key_counter(
    .clk(clk),
    .clrn(rst),
    .key_pressed(processed_key_pressed),
    // .key_released(processed_key_released),
    .key_count(key_count)
);

// ========== 七段数码管显示驱动 ==========
// 根据工程要求：
// 低两位（seg[1:0]）显示按键扫描码
// 中间两位（seg[3:2]）显示对应的ASCII码
// 高两位（seg[7:6]）显示按键总次数
// 当按键松开时，低四位全灭

// BCD转7段码转换函数
function [7:0] to_seg7(input [3:0] val);
    case(val)
        4'h0: to_seg7 = 8'b0000_0010;  // 0
        4'h1: to_seg7 = 8'b1001_1111;  // 1
        4'h2: to_seg7 = 8'b0010_0101;  // 2
        4'h3: to_seg7 = 8'b0000_1101;  // 3
        4'h4: to_seg7 = 8'b1001_1001;  // 4
        4'h5: to_seg7 = 8'b0100_1001;  // 5
        4'h6: to_seg7 = 8'b0100_0001;  // 6
        4'h7: to_seg7 = 8'b0001_1111;  // 7
        4'h8: to_seg7 = 8'b0000_0001;  // 8
        4'h9: to_seg7 = 8'b0000_1001;  // 9
        4'hA: to_seg7 = 8'b0001_0001;  // A
        4'hB: to_seg7 = 8'b1100_0001;  // b
        4'hC: to_seg7 = 8'b0110_0010;  // C
        4'hD: to_seg7 = 8'b1000_0101;  // d
        4'hE: to_seg7 = 8'b0110_0001;  // E
        4'hF: to_seg7 = 8'b0111_0001;  // F
        default: to_seg7 = 8'b1111_1111;
    endcase
endfunction




// 当按键被按下时，显示扫描码和ASCII码；松开时低四位全灭
wire [7:0] seg_low_two = to_seg7(processed_key_code[3:0]);
wire [7:0] seg_low_one = to_seg7(processed_key_code[7:4]);
wire [7:0] seg_mid_two = to_seg7(ascii_code[3:0]);
wire [7:0] seg_mid_one = to_seg7(ascii_code[7:4]);
// wire [7:0] seg_low_two = processed_key_pressed ? to_seg7(processed_key_code[3:0]) : 8'b1111_1111;
// wire [7:0] seg_low_one = processed_key_pressed ? to_seg7(processed_key_code[7:4]) : 8'b1111_1111;
// wire [7:0] seg_mid_two = processed_key_pressed ? to_seg7(ascii_code[3:0]) : 8'b1111_1111;
// wire [7:0] seg_mid_one = processed_key_pressed ? to_seg7(ascii_code[7:4]) : 8'b1111_1111;

// 高两位显示按键总次数
wire [7:0] seg_high_two = to_seg7(key_count[3:0]);
wire [7:0] seg_high_one = to_seg7(key_count[7:4]);

// 七段数码管显示模块
seg my_seg(
    .i_seg0(seg_low_two),
    .i_seg1(seg_low_one),
    .i_seg2(seg_mid_two),
    .i_seg3(seg_mid_one),
    .i_seg4(8'b1111_1111),  // 顶部第4位保留
    .i_seg5(8'b1111_1111),  // 顶部第5位保留
    .i_seg6(seg_high_two),
    .i_seg7(seg_high_one),
    .o_seg0(seg0),
    .o_seg1(seg1),
    .o_seg2(seg2),
    .o_seg3(seg3),
    .o_seg4(seg4),
    .o_seg5(seg5),
    .o_seg6(seg6),
    .o_seg7(seg7)
);

// ========== UART 模块 ==========
uart my_uart(
    .tx(uart_tx),
    .rx(uart_rx)
);

// ========== 调试输出 ==========
// 可将键盘模块的重要信号引至LED显示，用于调试
assign ledr[0] = keyboard_ready;        // FIFO非空标志
assign ledr[1] = keyboard_overflow;      // FIFO溢出标志
assign ledr[2] = processed_key_pressed;  // 按键被按下
assign ledr[3] = processed_key_released; // 按键被释放

// ========== 调试输出 ==========
assign processed_key_pressed_debug = processed_key_pressed;
assign processed_key_code_debug = processed_key_code;
assign ascii_code_debug = ascii_code;
assign key_count_debug = key_count;

endmodule

module vmem(
    input [9:0] h_addr, // 每行
    input [8:0] v_addr, // 每列
    output [23:0] vga_data
);

reg [23:0] vga_mem [524287:0];

initial begin
    $readmemh("resource/img_row.col", vga_mem);
    // $readmemh("resource/picture.hex", vga_mem);
end

assign vga_data = vga_mem[{h_addr, v_addr}]; // 生成 mif 的时候 也要 一列一列一列的扫描 而不是一行一行一行扫描

endmodule

// VCD 按行扫描 但为什么 生成 mif 的时候 是按列把img展开成 一维数组？以及 为什么是 用 {h_addr行, v_addr列} 来索引 而不是 {v_addr列, h_addr行} 来索引？

// 生成 mif 的时候对图片 列扫描 变成 一维数组
// y x addr 
// 0 0 0
// 1 0 1
// 2 0 2
// 3 0 3
// ...
// 0 1 <512>
// ...
// 0 2 <1024>
// ...
// 0 3 <1536>

// h_addr 每个clk +1 v_addr 在一行结束后再 +1
// 用 {h_addr,v_addr} 来作为 addr 索引 一维数组

//  h_addr     v_addr     addr:   对应原始图片的(y,x)  y 512 x 640
//     00         9‘b0    0           (0,0)
//     01         9‘b0    512         (0,1)
//     10         9‘b0    1024        (0,2)
//     11         9‘b0    1536        (0,3)

// 所以 相当于行扫描 符合 VCD 原理



// 如果 生成 mif 的时候 是按行扫描 把图像展开成一维数组 然后 使用 {v_addr列, h_addr行} 进行索引 一维数组：

// 生成 mif 的时候对图片 列扫描 变成 一维数组
// y x addr 
// 0 0 0
// 0 1 1
// 0 2 2
// 0 3 3
// ...
// 1 0 <640>
// ...
// 2 0 <1280>
// ...
// 3 0 <1920>

// h_addr 每个clk +1 v_addr 在一行结束后再 +1
// 用 {v_addr, h_addr} 来作为 addr 索引 一维数组

//    v_addr     h_addr   addr:   对应原始图片的(y,x)  y 512 x 640
//     00         9‘b1    0001      (0,0)
//     00         9‘b2    0002      (0,1)
//     00         9‘b3    0003      (0,2)
//     00         9‘b4    0004      (0,3)

// 这也是按行扫描呀 试试行不行
// 不行 生成的图片很奇怪 很多重影 而且 VCD下方是黑色的 没有被图片填满

// 只有用 $readmemh("resource/img_row.col", vga_mem); 和 assign vga_data = vga_mem[{h_addr, v_addr}]; 才行
// 用 $readmemh("resource/img_row.hex", vga_mem); 和 assign vga_data = vga_mem[{v_addr, h_addr}]; 就不行

// 为什么？

// 因为 {h_addr, v_addr} 的意义不仅仅是 {行，列}拼接，还是
// img 是 512 行高 v_addr 是 512 大小 
// 所以 {h_addr, v_addr} 计算的地址 = h_addr * 512 + v_addr
// 地址的物理意义是 有 h_addr 列 每一列 有 512 像素

// 而 {v_addr, h_addr} 的 h_addr 总共是 1024 大小，不是640 大小，计算出来的地址是
// v_addr * 1024 + h_addr 
// 这个地址的意思是 有 v_addr 个行，每个行是 1024 ，但实际上vcd每行只有 680 
// 而且 h_addr 只能遍历 0~ 639 遍历不到 1024那么大，所以这个地址是虚大的
// 所以最后生成的图片是 填不满 vcd 的 而且是重影的
