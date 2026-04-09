`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.03.2026 10:32:47
// Design Name: 
// Module Name: clk_divider
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module clk_div(
    input  clk100,
    input  rst,
    output reg clk_25  = 0,
    output reg clk_6p25 = 0
);
    reg [1:0] cnt25 = 0;
    reg [3:0] cnt6  = 0;

    always @(posedge clk100 or posedge rst) begin
        if (rst) begin
            cnt25  <= 0;
            clk_25 <= 0;
        end else if (cnt25 == 1) begin
            cnt25  <= 0;
            clk_25 <= ~clk_25;
        end else
            cnt25 <= cnt25 + 1;
    end

    always @(posedge clk100 or posedge rst) begin
        if (rst) begin
            cnt6    <= 0;
            clk_6p25 <= 0;
        end else if (cnt6 == 7) begin
            cnt6    <= 0;
            clk_6p25 <= ~clk_6p25;
        end else
            cnt6 <= cnt6 + 1;
    end
endmodule



