`timescale 1ns / 1ps
// EE2026 FDP Task Q
// A0311873E

module task_q(
    input [12:0] pixel_index,
    input clk,
    input BTND,
    output reg [15:0] oled_colour = 16'b00000_000000_00000
    );

    parameter GREEN  = 16'b00000_111111_00000;
    parameter RED    = 16'b11111_000000_00000;
    parameter BLUE   = 16'b00000_000000_11111;
    parameter YELLOW = 16'b11111_111111_00000;
    parameter BLACK  = 16'b00000_000000_00000;

    integer i = 0;
    integer j = 0;

    reg [31:0] cnt_200  = 0;
    reg [31:0] cnt_5000 = 0;
    wire clk_6p25mhz;
    my_clock clock_unit(.CLOCK(clk), .my_m_value(7), .my_clk(clk_6p25mhz));
    // wire send_pix, samp_pix;
    // wire [12:0] pixel_index;
    wire [10:0] x, y;
    reg [1:0] state = 2'b00;
    // reg [15:0] oled_colour = 16'b00000_000000_00000;
    reg [0:63] bitmap [0:95];
    reg prev_btnd = 0;

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
    reg flag = 1;

    // draw bitmap
    always @(posedge clk_6p25mhz) begin
        if (flag) begin
            for (i = 0; i < 96; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    bitmap[i][j] <= 0;
                end
            end
            for (i = 22; i < 24; i = i + 1) begin
                for (j = 36; j < 56; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            for (i = 20; i < 24; i = i + 1) begin
                for (j = 38; j < 40; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            for (i = 19; i < 27; i = i + 1) begin
                for (j = 54; j < 56; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            for (i = 39; i < 59; i = i + 1) begin
                for (j = 36; j <= 56; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            for (i = 70; i < 82; i = i + 1) begin
                for (j = 36; j < 38; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            for (i = 80; i < 82; i = i + 1) begin
                for (j = 38; j < 42; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            for (i = 78; i < 80; i = i + 1) begin
                for (j = 42; j < 44; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            for (i = 76; i < 78; i = i + 1) begin
                for (j = 44; j < 56; j = j + 1) begin
                    bitmap[i][j] <= 1;
                end
            end
            flag <= 0;
        end
    end

    always @(posedge clk_6p25mhz) begin
        if (bitmap[x][y] == 1) begin
            if (x < 30) oled_colour <= RED;
            else if (65 < x) oled_colour <= BLUE;
            else begin
                case (state)
                    0: oled_colour <= GREEN;
                    1: oled_colour <= RED;
                    2: oled_colour <= BLUE;
                    3: oled_colour <= YELLOW;
                    default: oled_colour <= BLACK;
                endcase
            end
        end
        else begin
            oled_colour <= BLACK;
        end

        if (cnt_200 == 0 && BTND == 1 && prev_btnd == 0) begin
            state <= state + 1;
            cnt_200 <= 1;
            cnt_5000 <= 1;
            prev_btnd <= 1;
        end
        else if (cnt_200 != 0) begin
            cnt_200 <= cnt_200 + 1;
            if (cnt_200 >= 1250000) cnt_200 <= 0;
        end

        if (cnt_5000 != 0 && prev_btnd == 1) begin
            cnt_5000 <= cnt_5000 + 1;
            if (cnt_5000 >= 31250000 || BTND == 0) begin
                cnt_5000 <= 0;
                prev_btnd <= 0;
            end
        end
    end


endmodule
