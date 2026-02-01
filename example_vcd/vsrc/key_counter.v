module key_counter (
    // 输入信号
    input clk,
    input clrn,
    input key_pressed,          // 来自scancode_processor
    // input key_released,         // 来自scancode_processor
    
    // 输出信号
    output reg [7:0] key_count // 按键总次数（16位，最多65535次）
);

// 用于记录key_pressed的前一个值
reg key_pressed_prev;

always @(posedge clk) begin
    if(clrn) begin
        // 复位：清除计数和状态
        key_count <= 8'h0000;
        key_pressed_prev <= 1'b0;
    end
    else begin
        // 更新前一个值
        key_pressed_prev <= key_pressed;
        
        // 在key_pressed的上升沿时递增计数
        // 上升沿条件：key_pressed == 1 && key_pressed_prev == 0
        if(key_pressed && !key_pressed_prev) begin
            key_count <= key_count + 1'b1;
        end
    end
end

endmodule
