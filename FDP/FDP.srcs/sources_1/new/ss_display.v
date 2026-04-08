`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/15/2023 03:05:11 PM
// Design Name: 
// Module Name: ss_display
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

module ss_display(
    input         clk,
    input         rst,
    input  [8:0]  player_hp,
    input  [3:0]  player_power,
    output reg [6:0] seg,
    output reg [3:0] an,
    output        dp
);
    assign dp = 1'b1;

    reg [17:0] refresh_cnt = 0;
    wire [1:0] digit_sel = refresh_cnt[17:16];

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh_cnt <= 0;
        else
            refresh_cnt <= refresh_cnt + 1;
    end

    wire [3:0] hp_hundreds = (player_hp >= 9'd200) ? 4'd2 :
                             (player_hp >= 9'd100) ? 4'd1 : 4'd0;
    wire [8:0] hp_rem1     = player_hp - ((hp_hundreds == 4'd2) ? 9'd200 :
                             (hp_hundreds == 4'd1) ? 9'd100 : 9'd0);
    wire [3:0] hp_tens     = (hp_rem1 >= 9'd90) ? 4'd9 :
                             (hp_rem1 >= 9'd80) ? 4'd8 :
                             (hp_rem1 >= 9'd70) ? 4'd7 :
                             (hp_rem1 >= 9'd60) ? 4'd6 :
                             (hp_rem1 >= 9'd50) ? 4'd5 :
                             (hp_rem1 >= 9'd40) ? 4'd4 :
                             (hp_rem1 >= 9'd30) ? 4'd3 :
                             (hp_rem1 >= 9'd20) ? 4'd2 :
                             (hp_rem1 >= 9'd10) ? 4'd1 : 4'd0;
    wire [8:0] hp_rem2     = hp_rem1 - {5'd0, hp_tens} * 9'd10;
    wire [3:0] hp_ones     = hp_rem2[3:0];

    reg [3:0] hex_digit;
    always @(*) begin
        case (digit_sel)
            2'd3: begin an = 4'b0111; hex_digit = hp_hundreds; end
            2'd2: begin an = 4'b1011; hex_digit = hp_tens;     end
            2'd1: begin an = 4'b1101; hex_digit = hp_ones;     end
            2'd0: begin an = 4'b1110; hex_digit = player_power; end
            default: begin an = 4'b1111; hex_digit = 4'd0;     end
        endcase
    end

    always @(*) begin
        case (hex_digit)
            4'd0:  seg = 7'b1000000;
            4'd1:  seg = 7'b1111001;
            4'd2:  seg = 7'b0100100;
            4'd3:  seg = 7'b0110000;
            4'd4:  seg = 7'b0011001;
            4'd5:  seg = 7'b0010010;
            4'd6:  seg = 7'b0000010;
            4'd7:  seg = 7'b1111000;
            4'd8:  seg = 7'b0000000;
            4'd9:  seg = 7'b0010000;
            4'd10: seg = 7'b0001000;
            4'd11: seg = 7'b0000011;
            4'd12: seg = 7'b1000110;
            4'd13: seg = 7'b0100001;
            4'd14: seg = 7'b0000110;
            4'd15: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end
endmodule
