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
    input         clk,
    input         rst,
    input  [15:0] seed,
    output [575:0] terrain_flat,  // 96 x 6 bits packed
    output reg    done
);

    reg [5:0] terrain [0:95];
    reg [15:0] lfsr;
    reg [6:0]  idx;
    reg        generating;

    // Pack output
    genvar i;
    generate
        for (i = 0; i < 96; i = i + 1) begin : pack_terrain
            assign terrain_flat[i*6 +: 6] = terrain[i];
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            lfsr <= seed;
            idx  <= 0;
            done <= 0;
            generating <= 1;
        end else if (generating) begin
            // LFSR step: taps at 16,15,13,4 (x^16+x^15+x^13+x^4+1)
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};

            // Terrain height: base 32, variation ¡À16 using top 5 bits
            // Range: 20..52 within 0..63
            terrain[idx] <= 6'd28 + lfsr[15:11] - 5'd16;

            if (idx == 7'd95) begin
                generating <= 0;
                done <= 1;
            end else begin
                idx <= idx + 1;
            end
        end
    end

    // Smoothing pass would require second state - keep simple for now

endmodule
