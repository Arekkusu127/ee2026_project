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
// Description: Shows HP by default, damage dealt for 5 seconds on hit
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
    input         game_started,
    input  [8:0]  player_hp,
    input         hit_event,
    input  [7:0]  hit_damage,
    output reg [6:0] seg,
    output reg [3:0] an,
    output        dp
);
    assign dp = 1'b1;

    // Refresh counter for multiplexing
    reg [17:0] refresh_cnt;
    wire [1:0] digit_sel = refresh_cnt[17:16];

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh_cnt <= 0;
        else
            refresh_cnt <= refresh_cnt + 1;
    end

    // 5 second timer for damage display (5 * 100MHz = 500,000,000)
    reg [28:0] damage_timer;
    reg        showing_damage;
    reg [7:0]  latched_damage;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            damage_timer   <= 0;
            showing_damage <= 0;
            latched_damage <= 0;
        end else begin
            if (hit_event) begin
                latched_damage <= hit_damage;
                showing_damage <= 1;
                damage_timer   <= 29'd499_999_999; // 5 seconds at 100MHz
            end else if (showing_damage) begin
                if (damage_timer == 0)
                    showing_damage <= 0;
                else
                    damage_timer <= damage_timer - 1;
            end
        end
    end

    // Value to display: either HP or damage
    wire [8:0] display_val = showing_damage ? {1'b0, latched_damage} : player_hp;

    // BCD conversion for up to 3 digits (0-511)
    wire [3:0] d_hundreds = (display_val >= 9'd200) ? 4'd2 :
                            (display_val >= 9'd100) ? 4'd1 : 4'd0;
    wire [8:0] rem1       = display_val - ((d_hundreds == 4'd2) ? 9'd200 :
                            (d_hundreds == 4'd1) ? 9'd100 : 9'd0);
    wire [3:0] d_tens     = (rem1 >= 9'd90) ? 4'd9 :
                            (rem1 >= 9'd80) ? 4'd8 :
                            (rem1 >= 9'd70) ? 4'd7 :
                            (rem1 >= 9'd60) ? 4'd6 :
                            (rem1 >= 9'd50) ? 4'd5 :
                            (rem1 >= 9'd40) ? 4'd4 :
                            (rem1 >= 9'd30) ? 4'd3 :
                            (rem1 >= 9'd20) ? 4'd2 :
                            (rem1 >= 9'd10) ? 4'd1 : 4'd0;
    wire [8:0] rem2       = rem1 - {5'd0, d_tens} * 9'd10;
    wire [3:0] d_ones     = rem2[3:0];

    // Indicator for damage mode: leftmost digit shows 'd' (displayed as 'd' pattern)
    // HP mode: leftmost shows 'H' pattern
    // Or simpler: show "dXXX" for damage, "HXXX" for HP
    
    reg [3:0] hex_digit;
    reg       show_special;  // flag for special character on digit 3
    
    always @(*) begin
        show_special = 0;
        case (digit_sel)
            2'd3: begin 
                an = 4'b0111; 
                if (!game_started) begin
                    hex_digit = 4'd0;  // blank-ish
                    show_special = 1;
                end else begin
                    show_special = 1;
                    hex_digit = showing_damage ? 4'd13 : 4'd11; // 'd' or 'H'
                end
            end
            2'd2: begin an = 4'b1011; hex_digit = d_hundreds; show_special = 0; end
            2'd1: begin an = 4'b1101; hex_digit = d_tens;     show_special = 0; end
            2'd0: begin an = 4'b1110; hex_digit = d_ones;     show_special = 0; end
            default: begin an = 4'b1111; hex_digit = 4'd0;    show_special = 0; end
        endcase
    end

    // 7-segment encoding
    // Standard hex + special chars:
    // 'H' = segments a off, b on, c on, d off, e on, f on, g on = 7'b0001001
    // 'd' = same as standard hex 'd' = 7'b0100001
    always @(*) begin
        if (!game_started) begin
            // Show dashes on menu
            seg = 7'b0111111;  // dash pattern
        end else if (show_special) begin
            case (hex_digit)
                4'd11: seg = 7'b0001001; // 'H'
                4'd13: seg = 7'b0100001; // 'd'
                default: seg = 7'b1111111;
            endcase
        end else begin
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
    end
endmodule
