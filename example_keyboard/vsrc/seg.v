module seg(

  input [7:0] i_seg0,
  input [7:0] i_seg1,
  input [7:0] i_seg2,
  input [7:0] i_seg3,
  input [7:0] i_seg4,
  input [7:0] i_seg5,
  input [7:0] i_seg6,
  input [7:0] i_seg7,
  output [7:0] o_seg0,
  output [7:0] o_seg1,
  output [7:0] o_seg2,
  output [7:0] o_seg3,
  output [7:0] o_seg4,
  output [7:0] o_seg5,
  output [7:0] o_seg6,
  output [7:0] o_seg7
);

// 输入输出直通，取反输出（阴极共享的七段数码管逻辑）
assign o_seg0 = i_seg0;
assign o_seg1 = i_seg1;
assign o_seg2 = i_seg2;
assign o_seg3 = i_seg3;
assign o_seg4 = i_seg4;
assign o_seg5 = i_seg5;
assign o_seg6 = i_seg6;
assign o_seg7 = i_seg7;

endmodule
