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
    input [9:0] h_addr,
    input [8:0] v_addr,
    output [23:0] vga_data
);

reg [23:0] vga_mem [524287:0];

initial begin
    $readmemh("resource/picture.hex", vga_mem);
end

assign vga_data = vga_mem[{h_addr, v_addr}];

endmodule
