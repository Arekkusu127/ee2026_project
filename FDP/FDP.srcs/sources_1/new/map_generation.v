`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qiang Jiayuan
// 
// Create Date: 20.03.2026 22:52:14
// Design Name: 
// Module Name: map_generation
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


module map_generation(
    input clk,
    input rst,
    input [6:0] x_range = 7'd95,
    input [5:0] y_range = 6'd63,
    input [3:0] max_elevation = 4'd6,
    input [4:0] top_margin = 5'd20,
    input [2:0] bottom_margin = 3'd5,
    input [3:0] edge_flat = 4'd10,
    output reg [5:0] terrain [0:95]
);

    // Generate only the left half, then mirror to enforce horizontal symmetry.
    reg [5:0] prev_y;
    integer i = 0;
    integer current_y;
    integer left_idx;
    integer right_idx;
    integer x_last;
    integer low_limit;
    integer high_limit;
    integer edge_y;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i <= 0;
            edge_y = y_range - bottom_margin;
            if (edge_y < top_margin) edge_y = top_margin;
            prev_y <= edge_y;
        end else begin 
            x_last = x_range;
            if (x_last > 95) x_last = 95;

            if (i < ((x_last + 2) >> 1)) begin
                left_idx = i;
                right_idx = x_last - i;

                low_limit = top_margin;
                high_limit = y_range - bottom_margin;
                if (high_limit < low_limit) high_limit = low_limit;

                edge_y = high_limit;

                // Keep flat land near both edges for easy spawn/landing.
                if (left_idx < edge_flat) begin
                    current_y = edge_y;
                end else begin
                    // Random walk with bounded slope changes.
                    current_y = prev_y + ($random % (2 * max_elevation + 1)) - max_elevation;
                    if (current_y < low_limit) current_y = low_limit;
                    if (current_y > high_limit) current_y = high_limit;
                end

                terrain[left_idx] <= current_y;
                if (right_idx != left_idx) begin
                    terrain[right_idx] <= current_y;
                end

                prev_y <= current_y;
                i <= i + 1;
            end
        end
    end

endmodule
