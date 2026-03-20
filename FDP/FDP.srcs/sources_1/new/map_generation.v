`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
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


module map_generation(input x_range = 640, input y_range = 480, input max_elevation = 25, input margin = 150, output [x_range-1:0] terrain);

    // For each x coordinate, generate a random y coordinate within elevation of previous point
    reg prev_y;
    integer i;

    always @(*) begin
        prev_y = y_range / 2; // Start in the middle of the y range
        for (i = 0; i < x_range; i = i + 1) begin
            // Generate a random elevation change between -max_elevation and +max_elevation
            // Update the current y coordinate based on the previous y and elevation change
            integer current_y;
            current_y = prev_y + ($random % (2 * max_elevation + 1)) - max_elevation;
            // Ensure current_y stays within the bounds of 0 and y_range
            if (current_y < margin) current_y = margin;
            if (current_y > (y_range - margin)) current_y = (y_range - margin);
            // Store the current y coordinate in the terrain output (this is a placeholder, actual implementation may vary)
            terrain[i] = current_y; // Assuming terrain is an array that can hold y coordinates for each x
            // Update prev_y for the next iteration
            prev_y = current_y;
        end
    end

endmodule
