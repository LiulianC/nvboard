module ps2_keyboard(clk,clrn,ps2_clk,ps2_data,data,
                    ready,nextdata_n,overflow);
    input clk;              // 系统时钟
    input clrn;             // 高电平有效复位信号
    input ps2_clk;          // PS/2键盘时钟信号
    input ps2_data;         // PS/2键盘数据信号
    input nextdata_n;       // 低电平有效，读取下一个数据

    output [7:0] data;      // 输出的扫描码（8位）
    output reg ready;       // 数据就绪标志，高电平表示FIFO中有数据
    output reg overflow;    // FIFO溢出标志
    
    // ========== 内部寄存器 ==========
    reg [9:0] buffer;       // 接收缓冲区，存储PS/2 11位数据（1个起始位+8个数据位+1个奇偶校验位+1个停止位）
    reg [7:0] fifo[7:0];    // 8深度的FIFO，存储已接收的扫描码
    reg [2:0] w_ptr,r_ptr;  // FIFO写指针和读指针，范围0-7循环计数
    reg [3:0] count;        // 接收计数器，用于计数已接收的PS/2数据位数（0-10）
    // ========== 边沿检测 ==========
    reg [2:0] ps2_clk_sync; // PS/2时钟同步器，用于检测下降沿（消除亚稳态）

    // 三级移位寄存器，同步外部ps2_clk信号
    always @(posedge clk) begin
        ps2_clk_sync <=  {ps2_clk_sync[1:0],ps2_clk};
    end

    // 下降沿检测：当ps2_clk_sync[2]=1且ps2_clk_sync[1]=0时，表示ps2_clk发生下降沿
    // 这是采样ps2_data的时刻
    wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];

    always @(posedge clk) begin
        if (clrn == 1) begin 
            // ========== 复位逻辑 ==========
            // 清空所有计数器和指针
            count <= 0;       // 接收位计数清零
            w_ptr <= 0;       // 写指针清零
            r_ptr <= 0;       // 读指针清零
            overflow <= 0;    // 溢出标志清零
            ready <= 0;       // 数据就绪标志清零
        end
        else begin
            // ========== 读取FIFO数据逻辑 ==========
            if ( ready ) begin 
                // FIFO中有数据时，可以读取下一个数据
                if(nextdata_n == 1'b0) 
                    // nextdata_n为0时，表示外部读取了一个扫描码
                begin
                    r_ptr <= r_ptr + 3'b1;  // 读指针递增（循环到0-7）
                    // 检查FIFO是否将要变空：当读指针加1后等于写指针时，FIFO为空
                    if(w_ptr==(r_ptr+1'b1))  
                        ready <= 1'b0;      // 清除数据就绪标志
                end
            end
            
            // ========== 接收PS/2数据逻辑 ==========
            if (sampling) begin
                // 在ps2_clk下降沿时采样ps2_data
                if (count == 4'd10) begin
                    // 已接收完整的11位数据，进行验证和存储
                    if ((buffer[0] == 0) &&     // 验证起始位为0
                        (ps2_data)       &&     // 验证停止位为1（当前ps2_data）
                        (^buffer[9:1])) begin   // 验证奇偶校验位：buffer[9:1]的异或结果为1（奇数个1）
                        // 验证通过，存储扫描码（去掉起始位和停止位，保留[8:1]）
                        fifo[w_ptr] <= buffer[8:1];
                        w_ptr <= w_ptr + 3'b1;  // 写指针递增（循环到0-7）
                        ready <= 1'b1;          // 设置数据就绪标志
                        // 检测溢出：当写指针加1后等于读指针时，表示FIFO满且即将被覆盖
                        overflow <= overflow | (r_ptr == (w_ptr + 3'b1));
                    end
                    count <= 0;                 // 重置计数器，准备接收下一帧数据
                end else begin
                    // 继续接收数据，当前采样的ps2_data存入buffer
                    buffer[count] <= ps2_data;  // 按接收顺序存储各位
                    count <= count + 3'b1;      // 计数器递增
                end
            end
        end
    end
    
    // ========== 数据输出 ==========
    assign data = fifo[r_ptr]; // 组合逻辑：始终输出当前读指针指向的FIFO数据

endmodule
