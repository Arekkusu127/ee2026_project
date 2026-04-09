`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2026 18:44:58
// Design Name: 
// Module Name: terrain_ram
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


module terrain_ram(
    input         clk,
    input  [6:0]  rd_addr_a,
    output reg [5:0] rd_data_a,
    input  [6:0]  rd_addr_b,
    output reg [5:0] rd_data_b,
    input         wr_en,
    input  [6:0]  wr_addr,
    input  [5:0]  wr_data
);
    (* ram_style = "block" *) reg [5:0] mem [0:127];

    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1)
            mem[i] = 6'd50;
    end

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
        rd_data_a <= mem[rd_addr_a];
        rd_data_b <= mem[rd_addr_b];
    end
endmodule

