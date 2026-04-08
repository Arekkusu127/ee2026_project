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
    input clk,
    input reset,
    input trail_clear,
    input trail_wr_en,
    input [12:0] trail_wr_addr,
    input [12:0] trail_rd_addr,
    output trail_rd_data
);
    // 6144 bits = 96*64
    // Use a block RAM style
    reg [63:0] trail_mem [0:95]; // 96 columns, 64 bits each (one per row)
    
    wire [6:0] wr_col = trail_wr_addr % 96;  // TODO: optimize
    wire [5:0] wr_row = trail_wr_addr / 96;
    
    wire [6:0] rd_col = trail_rd_addr % 96;
    wire [5:0] rd_row = trail_rd_addr / 96;
    
    // Read
    assign trail_rd_data = trail_mem[rd_col][rd_row];
    
    integer i;
    always @(posedge clk) begin
        if (reset || trail_clear) begin
            for (i = 0; i < 96; i = i + 1)
                trail_mem[i] <= 64'd0;
        end else if (trail_wr_en) begin
            trail_mem[wr_col][wr_row] <= 1'b1;
        end
    end
endmodule

