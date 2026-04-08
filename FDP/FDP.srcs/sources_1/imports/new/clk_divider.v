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

module clk_divider #(
    parameter DIV = 10_000_000
)(
    input  clk,
    input  rst,
    output tick
);

    reg [31:0] count;

    always @(posedge clk) begin
        if (rst)
            count <= 0;
        else if (count >= DIV - 1)
            count <= 0;
        else
            count <= count + 1;
    end

    assign tick = (count == 0);

endmodule


