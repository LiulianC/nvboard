module vga_ctrl(
    input           pclk,     //25MHz时钟
    input           reset,    //置位
    input  [23:0]   vga_data, //上层模块提供的VGA颜色数据
    output [9:0]    h_addr,   //提供给上层模块的当前扫描像素点坐标
    output [9:0]    v_addr,
    output          hsync,      // 行同步 
    output          vsync,      // 帧同步 
    output          valid,      //消隐信号
    output [7:0]    vga_r,      //红绿蓝颜色信号
    output [7:0]    vga_g,
    output [7:0]    vga_b
    );

  //640x480分辨率下的VGA参数设置
  parameter    h_frontporch = 96;       // 行同步负脉冲宽度为96个像素点时间
  parameter    h_active = 144;          // 开头需要的激活时间 96+48
  parameter    h_backporch = 784;       // 从零 到 刚显示一行的时间 96+48+640
  parameter    h_total = 800;           // 在标准的 640*480 的VGA上有效地显示一行信号需要 96+48+640+16=800 个像素点的时间，

  parameter    v_frontporch = 2;
  parameter    v_active = 35;           // 开头需要的激活时间 2+33
  parameter    v_backporch = 515;       // 从零 到 刚显示一帧的时间 2+33+480
  parameter    v_total = 525;           // 在标准的 640*480 的VGA上有效显示一帧图像需要2+33+480+10=525行时间

  //像素计数值
  reg [9:0]    x_cnt;   
  reg [9:0]    y_cnt;   

  wire         h_valid; 
  wire         v_valid; 

  always @(posedge reset or posedge pclk) //行像素计数 每次时钟 ++ 到达一行 重置为1
      if (reset == 1'b1)
        x_cnt <= 1;
      else
      begin
        if (x_cnt == h_total)
            x_cnt <= 1;
        else
            x_cnt <= x_cnt + 10'd1;
      end

  always @(posedge pclk)  //列像素计数 如果一帧结束 就重置1 否则 ++
      if (reset == 1'b1)
        y_cnt <= 1;
      else
      begin
        if (y_cnt == v_total & x_cnt == h_total) 
            y_cnt <= 1;
        else if (x_cnt == h_total)
            y_cnt <= y_cnt + 10'd1;
      end


  //生成同步信号 
  assign hsync = (x_cnt > h_frontporch); // 行同步 行同步信号是一个负脉冲，行同步信号有效后，由RGB端送出当前行显示的各像素点的RGB电压值
  assign vsync = (y_cnt > v_frontporch); // 帧同步 当一帧显示结束后，由帧同步信号送出一个负脉冲，重新开始从屏幕的左上端开始显示下一帧图像

  //生成消隐信号 VGA消隐信号（低有效）VGA_BLANK_N
  assign h_valid = (x_cnt > h_active) & (x_cnt <= h_backporch); // 除了 显示的640像素时间 其他时间是在消影
  assign v_valid = (y_cnt > v_active) & (y_cnt <= v_backporch); // 除了 现实的480行时间 其他时间是在消影
  assign valid = h_valid & v_valid; // 消影 是两者之与 比如 1&0=0 0才是消影

  //计算当前有效像素坐标 // 为什么多减去一个1？因为计数器x_cnt v_cnt是从1开始的。为什么cnt从1开始？因为 为了让 h_active v_active 这些变量是144 784 而不是 143 783. 不言自明
  assign h_addr = h_valid ? (x_cnt - 10'd145) : {10{1'b0}}; // x_cnt - 10'd145 减去 开头激活时多算的像素
  assign v_addr = v_valid ? (y_cnt - 10'd36) : {10{1'b0}};  // y_cnt - 10'd36 减去 开头激活时多算的行

  //设置输出的颜色值
  assign vga_r = vga_data[23:16];
  assign vga_g = vga_data[15:8];
  assign vga_b = vga_data[7:0];

endmodule