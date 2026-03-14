module CLOCK(
    input clk, 
    input [31:0] m, 
    output reg my_clk = 0
);
    reg [31:0] count = 0;
    always @(posedge clk) begin
        count  <= (count == m) ? 0 : count + 1;
        my_clk <= (count == 0) ? ~my_clk : my_clk;
    end
endmodule

module task_s (
    // input samp_pix,
    input [12:0] pixel_index,
    input  clk,
    input  btnL,
    input  btnR,
    output reg [15:0] oled_colour
);
    wire clk_6p25Mhz;
    CLOCK clk_6p25 (.clk(clk), .m(32'd7), .my_clk(clk_6p25Mhz));
    reg [21:0] move_counter = 0;
    reg        move_tick    = 0;
    always @(posedge clk) begin
        if (move_counter == 22'd2222221) begin
            move_counter <= 0;
            move_tick    <= 1;
        end else begin
            move_counter <= move_counter + 1;
            move_tick    <= 0;
        end
    end
    // wire send_pix, samp_pix;
    wire [12:0] pixel_index;
    // reg  [15:0] oled_colour;

    // Oled_Display unit_p (
    //     .clk(clk_6p25Mhz),
    //     .reset(0),
    //     .frame_begin(),
    //     .sending_pixels(send_pix),
    //     .sample_pixel(samp_pix),
    //     .pixel_index(pixel_index),
    //     .pixel_data(oled_colour),
    //     .cs(JC[0]), .sdin(JC[1]), .sclk(JC[3]),
    //     .d_cn(JC[4]), .resn(JC[5]), .vccen(JC[6]), .pmoden(JC[7])
    // );
    wire [6:0] x = pixel_index % 96;
    wire [5:0] y = pixel_index / 96;
    wire is_wall = (x>=24 && x<=28) && (y>=7 && y<=56);
    wire n8_top    = (x>=8  && x<=15 && y>=24 && y<=26);
    wire n8_mid    = (x>=8  && x<=15 && y>=31 && y<=33);
    wire n8_bot    = (x>=8  && x<=15 && y>=38 && y<=40);
    wire n8_tl     = (x>=8  && x<=10 && y>=24 && y<=33);
    wire n8_tr     = (x>=13 && x<=15 && y>=24 && y<=33);
    wire n8_bl     = (x>=8  && x<=10 && y>=33 && y<=40);
    wire n8_br     = (x>=13 && x<=15 && y>=33 && y<=40);
    wire is_num8 = n8_top | n8_mid | n8_bot | 
                   n8_tl  | n8_tr  | 
                   n8_bl  | n8_br;
    reg  [6:0] circle_x = 7'd70;
    reg [5:0] circle_y = 6'd32;    
    wire signed [7:0] dx = x - circle_x;
    wire signed [6:0] dy = y - circle_y;
    wire is_circle = (dx*dx + dy*dy) <= 81;
    localparam [6:0] MIN_CX = 7'd38;
    localparam [6:0] MAX_CX = 7'd85;
    reg [1:0] direction = 2'd0;

    reg btn_prev_r = 0;
    reg btn_prev_l = 0;
    
always @(posedge clk) begin
    if (btnR && !btn_prev_r)
        direction <= 2'd1;
    else if (btnL && !btn_prev_l)
        direction <= 2'd2;
    else if (move_tick) begin
        if (direction == 2'd1) begin
            if (circle_x >= MAX_CX)
                direction <= 2'd0;
            else
                circle_x <= circle_x + 1;
        end
        else if (direction == 2'd2) begin
            if (circle_x <= MIN_CX)
                direction <= 2'd0;
            else
                circle_x <= circle_x - 1;
        end
    end
    btn_prev_r <= btnR;
    btn_prev_l <= btnL;
end
    // always @(posedge clk) begin
    //     if (samp_pix) begin
    //         if (is_circle)
    //             oled_colour <= 16'hF800;
    //         else if (is_wall)
    //             oled_colour <= 16'hFFFF;
    //         else if (is_num8)
    //             oled_colour <= 16'h67E0;
    //         else
    //             oled_colour <= 16'h000F;
    //     end
    // end
    always @(posedge clk) begin
        if (is_circle)
                oled_colour <= 16'hF800;
            else if (is_wall)
                oled_colour <= 16'hFFFF;
            else if (is_num8)
                oled_colour <= 16'h67E0;
            else
                oled_colour <= 16'h0000;
    end

endmodule