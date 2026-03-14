`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT P NAME: Wang Wanru
//  STUDENT Q NAME: Wei Haowen
//  STUDENT R NAME: Qiang Jiayuan
//  STUDENT S NAME: Sun Shaohan
//
//////////////////////////////////////////////////////////////////////////////////

module clk_divider(input clk, input [31:0] base_freq, input [31:0] new_freq, output reg clk_out = 0);

    reg [31:0] counter = 0; // Counter to keep track of clock cycles
    reg [31:0] refresh;     // Calculate number of cycles for desired frequency
    always @(base_freq, new_freq) begin
        refresh = (new_freq == 0) ? 0 : (base_freq / (2 * new_freq)) - 1;
    end
    
    always @(posedge clk) begin
        // Increment the counter
        counter <= (counter >= refresh) ? 0 : counter + 1;
        // Toggle the output clock when the counter resets
        clk_out <= (counter == 0) ? ~clk_out : clk_out;
    end

endmodule

// module seven_seg(input clk, output [6:0] seg, output dp, output [3:0] an);

//     reg [3:0] digit = 0; // Current digit to display (0-9)
//     reg [15:0] count = 0; // Counter for timing

//     // Update the digit at 300Hz
//     wire clk_300hz;
//     clk_divider clk_div_inst (.clk(clk), .base_freq(100000000), .new_freq(300), .clk_out(clk_300hz));

//     // Seven-segment encoding
//     reg [7:0] seg_data;
//     reg [3:0] anode_data;
//     reg dp_sw;
//     always @(*) begin
//         case (state)
//             0: begin seg_data = 7'b0010010; anode_data = 4'b0111; dp_sw = 1'b1; end// '5'
//             1: begin seg_data = 7'b0010010; anode_data = 4'b1011; dp_sw = 1'b0; end // '5.'
//             2: begin seg_data = 7'b1000000; anode_data = 4'b1101; dp_sw = 1'b1; end // '0'
//             3: begin seg_data = 7'b1111001; anode_data = 4'b1110; dp_sw = 1'b1; end // '1'
//             default: begin seg_data = 7'b1111111; anode_data = 4'b1111; dp_sw = 1'b1; end // Blank
//         endcase
//     end

//     assign seg = seg_data;
//     assign dp = dp_sw;
//     assign an = anode_data;

//     // Cycle through stages at 300Hz
//     reg [1:0] state = 0;
//     always @(posedge clk_300hz) begin
//         state <= state + 1;
//         if (state >= 3)
//             state <= 0;
//     end

// endmodule


module Top_Student (input clk, 
                    input BTNU, BTND, BTNL, BTNR,
                    input sw1,
                    input [3:0] sw,
                    output [7:0] JC_out,
                    output [6:0] seg,
                    output [3:0] an,
                    output dp
                    );
    
    // reg [1:0] state = 2'b00;
    // wire [7:0] JP, JQ, JR, JS;
    reg [15:0] oled_colour;
    wire [15:0] color_p, color_q, color_r, color_s;
    wire [12:0] pixel_index;
    wire send_pix, samp_pix;
    task_p unit_p (.pixel_index(pixel_index), .CLOCK(clk), .BTNU(BTNU), .oled_colour(color_p));
    task_q unit_q (.pixel_index(pixel_index), .clk(clk), .BTND(BTND), .oled_colour(color_q));
    task_r unit_r (.pixel_index(pixel_index), .clk(clk), .sw1(sw1), .oled_colour(color_r));
    task_s unit_s (.pixel_index(pixel_index), .clk(clk), .btnL(BTNL), .btnR(BTNR), .oled_colour(color_s));
    // task_p unit_p (.CLOCK(clk), .BTNU(BTNU), .JC(JP));
    // task_q unit_q (.clk(clk), .BTND(BTND), .JC(JQ));
    // task_r unit_r (.clk(clk), .sw1(sw1), .JC(JR));
    // task_s unit_s (.clk(clk), .btnL(BTNL), .btnR(BTNR), .JC(JS));

    wire clk_6p25mhz;
    my_clock clock_unit(.CLOCK(clk), .my_m_value(7), .my_clk(clk_6p25mhz));
    

    Oled_Display unit(
        .clk(clk_6p25mhz),
        .reset(0),
        .frame_begin(),
        .sending_pixels(send_pix),
        .sample_pixel(samp_pix),
        .pixel_index(pixel_index),
        .pixel_data(oled_colour),
        .cs(JC_out[0]), .sdin(JC_out[1]), .sclk(JC_out[3]), .d_cn(JC_out[4]), .resn(JC_out[5]), .vccen(JC_out[6]), .pmoden(JC_out[7])
    );

    always @(posedge clk_6p25mhz) begin
        if (sw[3]) oled_colour = color_p;
        else if (sw[2]) oled_colour = color_q;
        else if (sw[1]) oled_colour = color_r;
        else if (sw[0]) oled_colour = color_s;
        else oled_colour = 16'b0;
    end

    // ----------------------------------------

    reg [3:0] digit = 0; // Current digit to display (0-9)
    reg [15:0] count = 0; // Counter for timing

    // Update the digit at 300Hz
    wire clk_300hz;
    clk_divider clk_div_inst (.clk(clk), .base_freq(100000000), .new_freq(300), .clk_out(clk_300hz));

    // Seven-segment encoding
    reg [7:0] seg_data;
    reg [3:0] anode_data;
    reg dp_sw;
    always @(*) begin
        case (state)
            0: begin seg_data = 7'b0010010; anode_data = 4'b0111; dp_sw = 1'b1; end// '5'
            1: begin seg_data = 7'b0010010; anode_data = 4'b1011; dp_sw = 1'b0; end // '5.'
            2: begin seg_data = 7'b1000000; anode_data = 4'b1101; dp_sw = 1'b1; end // '0'
            3: begin seg_data = 7'b1111001; anode_data = 4'b1110; dp_sw = 1'b1; end // '1'
            default: begin seg_data = 7'b1111111; anode_data = 4'b1111; dp_sw = 1'b1; end // Blank
        endcase
    end

    assign seg = seg_data;
    assign dp = dp_sw;
    assign an = anode_data;

    // Cycle through stages at 300Hz
    reg [1:0] state = 0;
    always @(posedge clk_300hz) begin
        state <= state + 1;
        if (state >= 3)
            state <= 0;
    end

endmodule
