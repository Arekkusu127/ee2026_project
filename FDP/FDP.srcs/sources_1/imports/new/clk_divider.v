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


`timescale 1ns / 1ps

module clk_divider(
    input clk,
    input [31:0] divisor,
    output reg tick = 0
);

    reg [31:0] counter = 0;

    always @(posedge clk) begin
        if (counter >= divisor - 1) begin
            counter <= 0;
            tick <= 1'b1;
        end else begin
            counter <= counter + 1;
            tick <= 1'b0;
        end
    end
endmodule

