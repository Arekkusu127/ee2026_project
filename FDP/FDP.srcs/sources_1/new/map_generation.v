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


module map_generation(input clk, input rst, input [9:0] x_range = 10'd640, input [9:0] y_range = 10'd480, input [4:0] max_elevation = 5'd25, input [9:0] margin = 10'd150, output reg [9:0] terrain [0:1023]);

    // For each x coordinate, generate a random y coordinate within elevation of previous point
    reg [9:0] prev_y;
    integer i = 0;
    integer current_y;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i <= 0;
            prev_y <= y_range / 2; // Reset to middle of the y range
        end else begin 
            if (i < x_range) begin
                // Generate random y coordinate based on previous y and max elevation
                current_y = prev_y + ($random % (2 * max_elevation + 1)) - max_elevation; // Random change in elevation
                // Ensure current_y is within bounds of y_range and margin
                if (current_y < margin) current_y = margin;
                if (current_y > y_range - margin) current_y = y_range - margin;
                
                terrain[i] <= current_y; // Store the generated y coordinate in the terrain array
                prev_y <= current_y; // Update previous y for next iteration
                i <= i + 1; // Move to the next x coordinate
            end
        end
    end

endmodule
