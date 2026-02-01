module scancode_processor (
    // 输入信号
    input clk,
    input clrn,
    input [7:0] scancode,       // 来自ps2_receiver的扫描码
    input scancode_ready,       // 扫描码就绪（ps2_receiver的ready信号）
    input scancode_valid,       // 扫描码有效（用户确认读取）
    
    // 输出信号
    output reg nextdata_n,      // 低电平有效一个周期，表示确认读取
    output reg [7:0] key_code,  // 当前按键的扫描码（通码）
    output reg key_pressed,     // 高电平表示按键被按下
    output reg key_released,    // 高电平脉冲表示按键释放
    output reg is_break_code    // 标记当前扫描码是否为断码前缀
);

// 状态定义
parameter IDLE = 2'b00;         // 等待扫描码
parameter BREAK_STATE = 2'b01;  // 等待断码

// 状态寄存器
reg [1:0] state, next_state;

// 用于检测scancode_ready的上升沿
reg scancode_ready_prev;

// 断码前缀值
localparam BREAK_CODE_PREFIX = 8'hF0;

// 用于产生nextdata_n的一个周期脉冲
reg nextdata_n_pulse;

// 状态转移和组合逻辑
always @(*) begin
    next_state = state;
    
    case(state)
        IDLE: begin
            // 当检测到scancode_ready的上升沿时处理新扫描码
            if(scancode_ready && !scancode_ready_prev) begin
                if(scancode == BREAK_CODE_PREFIX) begin
                    next_state = BREAK_STATE;
                end
                // 其他值为通码，保持在IDLE状态，在顺序逻辑中处理
            end
        end
        
        BREAK_STATE: begin
            // 等待断码数据
            if(scancode_ready && !scancode_ready_prev) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

// 时序逻辑：处理状态转移和输出
always @(posedge clk) begin
    if(clrn) begin
        state <= IDLE;
        key_code <= 8'h00;
        key_pressed <= 1'b0;
        key_released <= 1'b0;
        is_break_code <= 1'b0;
        scancode_ready_prev <= 1'b0;
        nextdata_n <= 1'b1;
        nextdata_n_pulse <= 1'b0;
    end
    else begin
        state <= next_state;
        scancode_ready_prev <= scancode_ready;
        
        // 默认清除脉冲信号
        key_released <= 1'b0;
        
        // nextdata_n脉冲逻辑：脉冲一个周期后回到高电平
        if(nextdata_n_pulse) begin
            nextdata_n <= 1'b1;
            nextdata_n_pulse <= 1'b0;
        end
        
        // 检测scancode_ready的上升沿
        if(scancode_ready && !scancode_ready_prev && scancode_valid) begin
            case(state)
                IDLE: begin
                    if(scancode == BREAK_CODE_PREFIX) begin
                        // 接收到断码前缀，产生nextdata_n脉冲以读取下一个数据
                        is_break_code <= 1'b1;
                        nextdata_n <= 1'b0;
                        nextdata_n_pulse <= 1'b1;
                    end
                    else begin
                        // 通码处理：更新key_code和key_pressed
                        key_code <= scancode;
                        key_pressed <= 1'b1;
                        is_break_code <= 1'b0;
                        // 产生nextdata_n脉冲：置零一个周期
                        nextdata_n <= 1'b0;
                        nextdata_n_pulse <= 1'b1;
                    end
                end
                
                BREAK_STATE: begin
                    // 断码处理：比较断码是否与当前 key_code 匹配
                    if(scancode == key_code) begin
                        key_released <= 1'b1;
                        key_pressed <= 1'b0;
                    end
                    is_break_code <= 1'b0;
                    // 产生nextdata_n脉冲：置零一个周期
                    nextdata_n <= 1'b0;
                    nextdata_n_pulse <= 1'b1;
                end
                
                default: ;
            endcase
        end
    end
end

endmodule

