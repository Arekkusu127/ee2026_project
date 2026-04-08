`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2026 20:05:38
// Design Name: 
// Module Name: trail_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 96x64 bitmap for projectile trail
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module trail_buffer (
    input         clk,
    input         reset,
    input         trail_clear,
    // Write port: set pixel at (wr_x, wr_y)
    input         trail_wr_en,
    input  [6:0]  trail_wr_x,
    input  [5:0]  trail_wr_y,
    // Read port: read pixel at (rd_x, rd_y)
    input  [6:0]  trail_rd_x,
    input  [5:0]  trail_rd_y,
    output        trail_rd_data
);
    // 96 columns x 64 rows, stored as 96 x 64-bit words
    reg [63:0] trail_mem [0:95];
    
    // Read - combinational
    assign trail_rd_data = (trail_rd_x < 7'd96 && trail_rd_y < 6'd64) ? 
                           trail_mem[trail_rd_x][trail_rd_y] : 1'b0;
    
    integer i;
    always @(posedge clk) begin
        if (reset || trail_clear) begin
            for (i = 0; i < 96; i = i + 1)
                trail_mem[i] <= 64'd0;
        end else if (trail_wr_en) begin
            if (trail_wr_x < 7'd96 && trail_wr_y < 6'd64)
                trail_mem[trail_wr_x][trail_wr_y] <= 1'b1;
        end
    end
endmodule


