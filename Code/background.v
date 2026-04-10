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
    reg [15:0] rom3 [0:6143];
  

    initial begin
    `ifdef SYNTHESIS
        $readmemb("../../FDP.srcs/resources_1/bg_rom0.bin", rom0);
        $readmemb("../../FDP.srcs/resources_1/bg_rom1.bin", rom1);
        $readmemb("../../FDP.srcs/resources_1/bg_rom2.bin", rom2);
        $readmemb("../../FDP.srcs/resources_1/demo.bin", rom3);
    `else
        $readmemb("../../../../FDP.srcs/resources_1/bg_rom0.bin", rom0);
        $readmemb("../../../../FDP.srcs/resources_1/bg_rom1.bin", rom1);
        $readmemb("../../../../FDP.srcs/resources_1/bg_rom2.bin", rom2);
        $readmemb("../../../../FDP.srcs/resources_1/demo.bin", rom3);
    `endif
    end

    wire [12:0] addr = ({vcount, 6'd0} + {vcount, 5'd0}) + {6'd0, hcount};

    // --- Original animation counter ---
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

    // --- Intro counter: holds rom3 for 300 frames (~5s at 60fps) ---
    localparam INTRO_FRAMES = 9'd300;
    reg [8:0] intro_cnt;
    reg intro_done;

    initial begin
        intro_cnt = 9'd0;
        intro_done = 1'b0;   // <-- ensures rom3 is shown first
    end

    always @(posedge CLOCK) begin
        if (!intro_done && frame_begin) begin
            if (intro_cnt == INTRO_FRAMES - 1) begin
                intro_done <= 1'b1;
            end else begin
                intro_cnt <= intro_cnt + 1;
            end
        end
    end

    // --- Pixel selection ---
    wire [15:0] auto_pixel  = bg_sel ? rom1[addr] : rom0[addr];
    wire [15:0] intro_pixel = intro_done ? auto_pixel : rom3[addr];
    assign pixel = game_started ? rom2[addr] : intro_pixel;
endmodule
