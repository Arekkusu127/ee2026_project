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

module map_generation #(
    parameter X_RANGE = 95,
    parameter Y_RANGE = 63,
    parameter MAX_ELEVATION = 6,
    parameter TOP_MARGIN = 20,
    parameter BOTTOM_MARGIN = 5,
    parameter EDGE_FLAT = 10
)(
    input clk,
    input rst,
    output reg [5:0] terrain [0:95]
);

    reg [5:0] prev_y;
    reg [6:0] i;
    reg done;

    // LFSR for pseudo-random number generation
    reg [15:0] lfsr;

    integer current_y;
    integer left_idx;
    integer right_idx;
    integer low_limit;
    integer high_limit;
    integer edge_y;
    integer half;
    integer rand_offset;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i <= 0;
            done <= 0;
            lfsr <= 16'hACE1;

            low_limit = TOP_MARGIN;
            high_limit = Y_RANGE - BOTTOM_MARGIN;
            if (high_limit < low_limit) high_limit = low_limit;

            prev_y <= high_limit[5:0];
        end else if (!done) begin
            // Advance LFSR every cycle (taps: 16,14,13,11)
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            low_limit = TOP_MARGIN;
            high_limit = Y_RANGE - BOTTOM_MARGIN;
            if (high_limit < low_limit) high_limit = low_limit;
            edge_y = high_limit;

            half = (X_RANGE + 2) >> 1;

            if (i < half) begin
                left_idx = i;
                right_idx = X_RANGE - i;

                if (left_idx < EDGE_FLAT) begin
                    current_y = edge_y;
                end else begin
                    // Use LFSR bits for random walk: range [-MAX_ELEVATION, +MAX_ELEVATION]
                    // lfsr[3:0] gives 0-15, subtract MAX_ELEVATION, then clamp
                    rand_offset = lfsr[3:0];
                    if (rand_offset > (2 * MAX_ELEVATION))
                        rand_offset = 2 * MAX_ELEVATION;
                    current_y = prev_y + rand_offset - MAX_ELEVATION;

                    if (current_y < low_limit) current_y = low_limit;
                    if (current_y > high_limit) current_y = high_limit;
                end

                terrain[left_idx] <= current_y[5:0];
                if (right_idx != left_idx)
                    terrain[right_idx] <= current_y[5:0];

                prev_y <= current_y[5:0];
                i <= i + 1;
            end else begin
                done <= 1;
            end
        end
    end
endmodule
