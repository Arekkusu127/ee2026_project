`timescale 1ns / 1ps
// EE2026 FDP Task R
// A0311873E
module task_r(
    input [12:0] pixel_index,
    input clk,
    input sw1,
    output reg [15:0] oled_colour = 16'b0
    );

    parameter GREEN  = 16'b00000_111111_00000;
    parameter RED    = 16'b11111_000000_00000;
    parameter BLUE   = 16'b00000_000000_11111;
    parameter YELLOW = 16'b11111_111111_00000;
    parameter BLACK  = 16'b00000_000000_00000;
    parameter LBLUE  = 16'b00111_000111_11111;

    integer i = 0;
    integer j = 0;

    wire clk_6p25mhz;
    wire clk_25hz;
    my_clock clock_unit_1(.CLOCK(clk),         .my_m_value(7),      .my_clk(clk_6p25mhz));
    my_clock clock_unit_2(.CLOCK(clk_6p25mhz), .my_m_value(124999), .my_clk(clk_25hz   ));
    reg direction = 0; // 0: right, 1: left

    wire send_pix, samp_pix;
    wire [12:0] pixel_index;
    wire [10:0] x, y;
    // reg [15:0] oled_colour = 16'b00000_000000_00000;
    // Oled_Display unit_p(
    //     .clk(clk_6p25mhz),
    //     .reset(0),
    //     .frame_begin(),
    //     .sending_pixels(send_pix),
    //     .sample_pixel(samp_pix),
    //     .pixel_index(pixel_index),
    //     .pixel_data(oled_colour),
    //     .cs(JC[0]), .sdin(JC[1]), .sclk(JC[3]), .d_cn(JC[4]), .resn(JC[5]), .vccen(JC[6]), .pmoden(JC[7])
    // );
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;

    // draw "0"
    wire char_0 = ((x >= 40 && x <= 56) && (y >= 25 && y <= 28 || y >= 50 && y <= 53))
               || ((y >= 25 && y <= 53) && (x >= 40 && x <= 43 || x >= 53 && x <= 56));

    // draw "5"
    reg [8:0] NW_x = 0;
    wire char_5 = ((x >= NW_x && x <= NW_x + 16) && (y >= 25 && y <= 28 || y>= 36 && y <= 39 || y >= 50 && y <= 53))
                || ((y >= 25 && y <= 39) && (x >= NW_x && x <= NW_x + 3))
                || ((y >= 39 && y <= 53) && (x >= NW_x + 13 && x <= NW_x + 16));
    
    always @(posedge clk_25hz) begin
        if (sw1 == 1) begin
            if (direction == 0) begin
                if (NW_x < 75) NW_x <= NW_x + 1;
                else direction <= 1;
            end
            else begin
                if (NW_x > 0) NW_x <= NW_x - 1;
                else direction <= 0;
            end
        end
    end

    always @(posedge clk_6p25mhz) begin
        if (char_5) oled_colour <= BLUE;
        else if (char_0) oled_colour <= YELLOW;
        else oled_colour <= BLACK;
    end




endmodule
