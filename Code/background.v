`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2026 11:19:19
// Design Name: 
// Module Name: background
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


module background(
    input CLOCK,
    input game_started,
    input frame_begin,
    input  [6:0] hcount,
    input  [5:0] vcount,
    output [15:0] pixel
);
    reg [15:0] rom0 [0:6143];
    reg [15:0] rom1 [0:6143];
    reg [15:0] rom2 [0:6143];

    initial begin
    `ifdef SYNTHESIS
        $readmemb("../../FDP.srcs/resources_1/bg_rom0.bin", rom0);
        $readmemb("../../FDP.srcs/resources_1/bg_rom1.bin", rom1);
        $readmemb("../../FDP.srcs/resources_1/bg_rom2.bin", rom2);
    `else
        $readmemb("../../../../FDP.srcs/resources_1/bg_rom0.bin", rom0);
        $readmemb("../../../../FDP.srcs/resources_1/bg_rom1.bin", rom1);
        $readmemb("../../../../FDP.srcs/resources_1/bg_rom2.bin", rom2);
    `endif
    end

    wire [12:0] addr = ({vcount, 6'd0} + {vcount, 5'd0}) + {6'd0, hcount};

    reg [7:0] frame_cnt;
    reg bg_sel;

    always @(posedge CLOCK) begin
        if (frame_begin) begin
            if (frame_cnt == 8'd202) begin
                frame_cnt <= 0;
                bg_sel <= ~bg_sel;
            end else begin
                frame_cnt <= frame_cnt + 1;
            end
        end    
    end

    wire [15:0] auto_pixel = bg_sel ? rom1[addr] : rom0[addr]; 
    assign pixel = game_started ? rom2[addr] : auto_pixel;
endmodule
