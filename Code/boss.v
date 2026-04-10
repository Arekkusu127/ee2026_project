`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2026 11:19:19
// Design Name: 
// Module Name: boss
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


module boss(
    input frame_begin,
    input [5:0] x_pos,
    input [5:0] y_pos,
    output  [15:0] pixel,
    output visible
);
    reg [15:0] rom [0:1999];
    initial begin
        `ifdef SYNTHESIS
            $readmemb("../../FDP.srcs/resources_1/boss.bin", rom);
        `else
            $readmemb("../../../../FDP.srcs/resources_1/boss.bin", rom);
        `endif
    end
    wire [10:0] addr = y_pos * 40 + x_pos; // 40 pixels per row
    assign pixel = rom[addr];
    wire [4:0] r = pixel[15:11];
    wire [5:0] g = pixel[10:5];
    wire [4:0] b = pixel[4:0];
    assign visible = !( (r >= 28) && (g >= 45) && (g <= 55) && (b >= 28) );

endmodule
