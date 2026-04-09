`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2026 23:34:48
// Design Name: 
// Module Name: girl_ctrl
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


module girl_ctrl(
    input CLOCK,
    input frame_begin,
    input BTNR,
    input BTNL,
    input game_mode,
    output reg[6:0] girl_x  // left edge x position
    );
    localparam GIRL_W = 30; // change size and boundary here
    localparam GIRL_H = 30;
    localparam LEFT_BOUND = 0; // left boundary for girl
    localparam RIGHT_BOUND = 50;
    


    reg girl_dir = 1'b0; // moving left
    reg [7:0] cnt = 0;

    initial begin
        girl_x = LEFT_BOUND;
    end
    always @(posedge CLOCK) begin
        if (game_mode && frame_begin) begin
            if (cnt == 8'd170) begin
                cnt <= 0;
                // Update direction based on button input
                if      (BTNR) girl_dir = 1'b1; // move right
                else if (BTNL) girl_dir = 1'b0; // move left
                if (girl_dir) begin
                    if (girl_x < RIGHT_BOUND) begin
                        girl_x <= girl_x + 1;
                    end
                end else if (!girl_dir) begin
                    if (girl_x > LEFT_BOUND) begin
                        girl_x <= girl_x - 1;
                    end
                end
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

endmodule
