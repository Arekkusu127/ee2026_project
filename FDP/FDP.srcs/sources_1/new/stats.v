`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qiang Jiayuan
// 
// Create Date: 20.03.2026 21:13:52
// Design Name: 
// Module Name: stats
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

module stats(
    input  [3:0] entity_id,   // 0 = player0, 1 = player1, 2+ = enemies
    output reg [7:0] base_hp,
    output reg [7:0] base_atk,
    output reg [7:0] base_def,
    output reg [2:0] width,    // half-width in pixels
    output reg [2:0] height    // half-height in pixels
);

    always @(*) begin
        case (entity_id)
            4'd0: begin  // Player 0
                base_hp  = 8'd150;
                base_atk = 8'd20;
                base_def = 8'd5;
                width    = 3'd1;
                height   = 3'd2;
            end
            4'd1: begin  // Player 1
                base_hp  = 8'd150;
                base_atk = 8'd20;
                base_def = 8'd5;
                width    = 3'd1;
                height   = 3'd2;
            end
            default: begin
                base_hp  = 8'd100;
                base_atk = 8'd15;
                base_def = 8'd3;
                width    = 3'd1;
                height   = 3'd2;
            end
        endcase
    end

endmodule
