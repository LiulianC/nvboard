// 扫描码转ASCII码模块
// 使用MuxKeyWithDefault实现ROM查找表
// 根据PS/2扫描码转换为对应的ASCII码

module scancode_to_ascii (
    // 输入信号
    input clk,
    input clrn,
    input [7:0] scancode,      // PS/2扫描码
    input lookup_valid,        // 查找使能信号
    
    // 输出信号
    output reg [7:0] ascii_code,   // 对应的ASCII码
    output reg lookup_ready        // 转换完成标志
);

    // 组合逻辑：使用MuxKeyWithDefault实现查找表
    // 参数说明：
    // NR_KEY = 45（支持45个不同的扫描码）
    // KEY_LEN = 8（扫描码宽度8位）
    // DATA_LEN = 8（ASCII码宽度8位）
    // lut格式：{scancode1, ascii1, scancode2, ascii2, ..., scancode45, ascii45}
    
    wire [7:0] ascii_out;
    
    MuxKeyWithDefault #(52, 8, 8) i0 (
        .out(ascii_out),
        .key(scancode),
        .default_out(8'h00),  // 不支持的扫描码返回0x00
        .lut({
            // 功能键
            8'h01, 8'h1B,  // Esc -> ESC
            8'h0E, 8'h08,  // Backspace -> BS
            8'h0F, 8'h09,  // Tab -> TAB
            8'h1C, 8'h0D,  // Enter -> CR
            
            // 数字键（顶部行）
            8'h29, 8'h60,  // ` / ~ -> `
            8'h02, 8'h31,  // 1 / ! -> 1
            8'h03, 8'h32,  // 2 / @ -> 2
            8'h04, 8'h33,  // 3 / # -> 3
            8'h05, 8'h34,  // 4 / $ -> 4
            8'h06, 8'h35,  // 5 / % -> 5
            8'h07, 8'h36,  // 6 / ^ -> 6
            8'h08, 8'h37,  // 7 / & -> 7
            8'h09, 8'h38,  // 8 / * -> 8
            8'h0A, 8'h39,  // 9 / ( -> 9
            8'h0B, 8'h30,  // 0 / ) -> 0
            8'h0C, 8'h2D,  // - / _ -> -
            8'h0D, 8'h3D,  // = / + -> =
            
            // 字母键（QWERTY行）
            8'h10, 8'h71,  // q / Q -> q
            8'h11, 8'h77,  // w / W -> w
            8'h12, 8'h65,  // e / E -> e
            8'h13, 8'h72,  // r / R -> r
            8'h14, 8'h74,  // t / T -> t
            8'h15, 8'h79,  // y / Y -> y
            8'h16, 8'h75,  // u / U -> u
            8'h17, 8'h69,  // i / I -> i
            8'h18, 8'h6F,  // o / O -> o
            8'h19, 8'h70,  // p / P -> p
            8'h1A, 8'h5B,  // [ / { -> [
            8'h1B, 8'h5D,  // ] / } -> ]
            
            // 字母键（ASDF行）
            8'h1E, 8'h61,  // a / A -> a
            8'h1F, 8'h73,  // s / S -> s
            8'h20, 8'h64,  // d / D -> d
            8'h21, 8'h66,  // f / F -> f
            8'h22, 8'h67,  // g / G -> g
            8'h23, 8'h68,  // h / H -> h
            8'h24, 8'h6A,  // j / J -> j
            8'h25, 8'h6B,  // k / K -> k
            8'h26, 8'h6C,  // l / L -> l
            8'h27, 8'h3B,  // ; / : -> ;
            8'h28, 8'h27,  // ' / " -> '
            8'h2B, 8'h5C,  // \ / | -> \
            
            // 字母键（ZXCV行）
            8'h2C, 8'h7A,  // z / Z -> z
            8'h2D, 8'h78,  // x / X -> x
            8'h2E, 8'h63,  // c / C -> c
            8'h2F, 8'h76,  // v / V -> v
            8'h30, 8'h62,  // b / B -> b
            8'h31, 8'h6E,  // n / N -> n
            8'h32, 8'h6D,  // m / M -> m
            8'h33, 8'h2C,  // , / < -> ,
            8'h34, 8'h2E,  // . / > -> .
            8'h35, 8'h2F,  // / / ? -> /
            
            // 空格键
            8'h39, 8'h20   // SpaceBar -> Space
        })
    );
    
    // 时序逻辑：处理lookup_valid信号并输出结果
    always @(posedge clk) begin
        if(clrn) begin
            ascii_code <= 8'h00;
            lookup_ready <= 1'b0;
        end
        else begin
            if(lookup_valid) begin
                ascii_code <= ascii_out;
                lookup_ready <= 1'b1;
            end
            else begin
                lookup_ready <= 1'b0;
            end
        end
    end

endmodule


