`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT A NAME: 
//  STUDENT B NAME:
//  STUDENT C NAME: 
//  STUDENT D NAME:  
//
//////////////////////////////////////////////////////////////////////////////////
module clk_6p5mhz(
    input CLOCK,
    output reg SLOW_CLOCK
    );
    reg [2:0] counter = 0;
    initial SLOW_CLOCK = 0;
    always @(posedge CLOCK)begin
        counter <= (counter == 7) ? 0 : counter + 1;
        SLOW_CLOCK <= (counter == 0) ? ~SLOW_CLOCK : SLOW_CLOCK;
    end
endmodule
module clk_1ms(
    input CLOCK,
    output reg COUNT
    );
    reg [16:0]counter = 0;
    initial COUNT = 0;
    always @(posedge CLOCK)begin
        counter <= (counter == 99999)? 0 : counter +1;
        COUNT <= (counter == 99999);
    end
endmodule
module debouncer(
    input CLOCK,
    input BTNU,
    output reg DB_BTNU
);
    wire tick_1ms;
    reg [7:0] debounce_cnt = 0;
    reg btn_active = 0;
    reg btn_prev = 0;
    reg btn_pulse = 0;
    clk_1ms unit_u (.CLOCK(CLOCK), .COUNT(tick_1ms) );
    always @(posedge CLOCK)begin
        btn_pulse <= 0;
        if (tick_1ms)begin
            if (!btn_active) begin
                if (BTNU && !btn_prev)begin
                    btn_pulse <= 1;
                    btn_active <= 1;
                    debounce_cnt <= 0;
                end
            end
            else begin
                if (debounce_cnt < 200)begin
                    debounce_cnt <= debounce_cnt + 1;
                end
                else begin
                    if (!BTNU)begin
                        btn_active <= 0;
                    end
                end
            end
            btn_prev <= BTNU;
        end
        DB_BTNU <= btn_pulse;
    end
endmodule


module task_p (
    // input sample_pix,
    input [12:0] pixel_index, input CLOCK, input BTNU,
                output reg [15:0] oled_colour);
       reg display_on = 1;
       wire clk_6p5MHZ;
       wire db_btnu;
       wire send_pix, samp_pix;
    //    wire [12:0] pixel_index;
       wire [6:0] x = pixel_index % 96;   
       wire [5:0] y = pixel_index / 96;   
    //    reg [15:0] oled_colour;
       localparam RED = 16'hF800;
       localparam GREEN = 16'h07E0;
       localparam WHITE = 16'hFFFF;
       localparam BLACK = 16'h0000;
       wire circle = ((x-8)*(x-8) + (y-8)*(y-8))<= 36;
       wire d6_a = (x>=20  && x<=49 && y>=6  && y<=13);  // top bar
       wire d6_b = (x>=20  && x<=27 && y>=14 && y<=27);  // top-left
       wire d6_d = (x>=20  && x<=49 && y>=28 && y<=35);  // middle bar
       wire d6_e = (x>=20  && x<=27 && y>=36 && y<=49);  // bot-left
       wire d6_f = (x>=42 && x<=49 && y>=36 && y<=49);  // bot-right
       wire d6_g = (x>=20  && x<=49 && y>=50 && y<=57);  // bottom bar
       wire left_digit = d6_a | d6_b | d6_d | d6_e | d6_f | d6_g;
       wire d3_a = (x>=58 && x<=87 && y>=6  && y<=13);  // top bar
       wire d3_c = (x>=80 && x<=87 && y>=14 && y<=27);  // top-right
       wire d3_d = (x>=58 && x<=87 && y>=28 && y<=35);  // middle bar
       wire d3_f = (x>=80 && x<=87 && y>=36 && y<=49); // bot-right
       wire d3_g = (x>=58 && x<=87 && y>=50 && y<=57);  // bottom bar
       wire right_digit = d3_a | d3_c | d3_d | d3_f | d3_g;
       clk_6p5mhz unit_b (.CLOCK(CLOCK), .SLOW_CLOCK(clk_6p5MHZ) );
       debouncer unit_d (.CLOCK(CLOCK), .BTNU(BTNU), .DB_BTNU(db_btnu) );
    //    Oled_Display unit_p (
    //    .clk(clk_6p5MHZ),
    //    .reset(0),
    //    .frame_begin(),
    //    .sending_pixels(send_pix),
    //    .sample_pixel(sample_pix),
    //    .pixel_index(pixel_index),
    //    .pixel_data(oled_colour),
    //    .cs(JC[0]), .sdin(JC[1]), .sclk(JC[3]), .d_cn(JC[4]), .resn(JC[5]), .vccen(JC[6]), .pmoden(JC[7]) );
always @(posedge CLOCK)begin
    if (db_btnu)
        display_on <= ~display_on;
end
always @(posedge CLOCK) begin
    // if (sample_pix) begin
        if (!display_on)
            oled_colour <= BLACK;
        else if (circle)
            oled_colour <= WHITE;
        else if (left_digit)
            oled_colour <= RED;
        else if (right_digit)
            oled_colour <= GREEN;
        else
            oled_colour <= BLACK;
    // end
end
endmodule