module led(
  input clk,
  input rst,
  input [4:0] btn,
  input [7:0] sw,
  output [15:0] ledr
);
  reg [31:0] count;
  reg [15:0] led;  // 改成 16 位，直接对应输出
  
  always @(posedge clk) begin
    if (rst) begin 
      led <= 16'h0001;  // 最右边的灯亮起
      count <= 0;
    end
    else begin
      if (count == 0) led <= {led[14:0], led[15]};  // 左移（从右往左流动）
      count <= (count >= 5000000 ? 32'b0 : count + 1);
    end
  end

  // assign ledr = led; 

endmodule
