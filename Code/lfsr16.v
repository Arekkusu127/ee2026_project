`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qiang Jiayuan
// 
// Create Date: 08.04.2026 18:41:41
// Design Name: 
// Module Name: lfsr16
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


module lfsr16(
    input         clk,
    input         rst,
    output reg [15:0] rng
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            rng <= 16'hACE1;
        else
            rng <= {rng[14:0], rng[15] ^ rng[13] ^ rng[12] ^ rng[10]};
    end
endmodule
