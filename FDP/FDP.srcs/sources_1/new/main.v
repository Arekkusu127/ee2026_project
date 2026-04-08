`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT P NAME: Wang Wanru
//  STUDENT Q NAME: Wei Haowen
//  STUDENT R NAME: Qiang Jiayuan
//  STUDENT S NAME: Sun Shaohan
//
//  Integrate all functions together
// 
//////////////////////////////////////////////////////////////////////////////////

module main(
    input  clk,          // 100 MHz
    input  btnU,         // angle up
    input  btnD,         // angle down
    input  btnL,         // power down
    input  btnR,         // power up
    input  btnC,         // fire / confirm
    input  [15:0] sw,    // sw[3:0] skill select
    output [7:0] seg,    // 7-segment cathodes
    output [3:0] an,     // 7-segment anodes
    output [15:0] led,   // debug LEDs
    // OLED SPI
    output oled_cs,
    output oled_sdin,
    output oled_sclk,
    output oled_d_cn,
    output oled_resn,
    output oled_vccen,
    output oled_pmoden
);

    // -------------------------------------------------------
    // Clock generation: 6.25 MHz for OLED SPI
    // -------------------------------------------------------
    reg [3:0] clk_div;
    reg       clk_6p25;
    always @(posedge clk) begin
        clk_div <= clk_div + 1;
        if (clk_div == 4'd15)
            clk_6p25 <= ~clk_6p25;
    end

    // -------------------------------------------------------
    // Game tick (10 Hz) and animation tick (30 Hz)
    // -------------------------------------------------------
    wire tick_10hz, tick_30hz;
    clk_divider #(.DIV(10_000_000)) u_tick10 (
        .clk(clk), .rst(1'b0), .tick(tick_10hz)
    );
    clk_divider #(.DIV(3_333_333)) u_tick30 (
        .clk(clk), .rst(1'b0), .tick(tick_30hz)
    );

    // -------------------------------------------------------
    // OLED display
    // -------------------------------------------------------
    wire [12:0] pixel_index;   // 0..6143
    wire        sample_pixel;
    wire [15:0] oled_colour;

    Oled_Display u_oled (
        .clk(clk_6p25),
        .reset(1'b0),
        .frame_begin(),
        .sending_pixels(),
        .sample_pixel(sample_pixel),
        .pixel_index(pixel_index),
        .pixel_data(oled_colour),
        .cs(oled_cs),
        .sdin(oled_sdin),
        .sclk(oled_sclk),
        .d_cn(oled_d_cn),
        .resn(oled_resn),
        .vccen(oled_vccen),
        .pmoden(oled_pmoden)
    );

    // -------------------------------------------------------
    // Division-free pixel coordinate recovery
    // -------------------------------------------------------
    reg [6:0] px_x;  // 0..95
    reg [5:0] px_y;  // 0..63

    always @(posedge clk_6p25) begin
        if (pixel_index == 0) begin
            px_x <= 0;
            px_y <= 0;
        end else if (sample_pixel) begin
            if (px_x == 7'd95) begin
                px_x <= 0;
                px_y <= px_y + 1;
            end else begin
                px_x <= px_x + 1;
            end
        end
    end

    // -------------------------------------------------------
    // Map generation
    // -------------------------------------------------------
    wire [575:0] terrain_flat;  // 96 x 6 bits
    wire         map_done;

    map_generation u_map (
        .clk(clk),
        .rst(1'b0),
        .seed(16'hACE1),
        .terrain_flat(terrain_flat),
        .done(map_done)
    );

    // Unpack terrain locally
    wire [5:0] terrain [0:95];
    genvar gi;
    generate
        for (gi = 0; gi < 96; gi = gi + 1) begin : unpack_terrain
            assign terrain[gi] = terrain_flat[gi*6 +: 6];
        end
    endgenerate

    // -------------------------------------------------------
    // Game state
    // -------------------------------------------------------
    wire [2:0]  phase;
    wire        turn;          // 0 = player 0, 1 = player 1
    wire [7:0]  angle;
    wire [3:0]  power;
    wire [4:0]  energy;
    wire [15:0] hp_flat;       // 2 x 8 bits
    wire        game_over;
    wire        winner;

    // Attack interface
    wire        fire_trigger;
    wire        hit_flag;
    wire [7:0]  damage;
    wire [3:0]  skill_id;

    // Projectile position
    wire [6:0]  proj_x;
    wire [5:0]  proj_y;
    wire        proj_active;

    game_state u_gs (
        .clk(clk),
        .tick(tick_10hz),
        .btnU(btnU),
        .btnD(btnD),
        .btnL(btnL),
        .btnR(btnR),
        .btnC(btnC),
        .sw(sw[3:0]),
        .terrain_flat(terrain_flat),
        .map_done(map_done),
        .hit_flag(hit_flag),
        .damage(damage),
        .proj_active(proj_active),
        .phase(phase),
        .turn(turn),
        .angle(angle),
        .power(power),
        .energy(energy),
        .hp_flat(hp_flat),
        .fire_trigger(fire_trigger),
        .skill_id(skill_id),
        .game_over(game_over),
        .winner(winner)
    );

    wire [7:0] hp0 = hp_flat[7:0];
    wire [7:0] hp1 = hp_flat[15:8];

    // -------------------------------------------------------
    // Player positions (fixed for now)
    // -------------------------------------------------------
    wire [6:0] p0_x = 7'd15;
    wire [5:0] p0_y = terrain[15] - 6'd3;
    wire [6:0] p1_x = 7'd80;
    wire [5:0] p1_y = terrain[80] - 6'd3;

    // -------------------------------------------------------
    // Attack / projectile
    // -------------------------------------------------------
    attack u_atk (
        .clk(clk),
        .tick(tick_30hz),
        .fire(fire_trigger),
        .angle(angle),
        .power(power),
        .skill_id(skill_id),
        .start_x(turn ? p1_x : p0_x),
        .start_y(turn ? p1_y : p0_y),
        .target_x(turn ? p0_x : p1_x),
        .target_y(turn ? p0_y : p1_y),
        .terrain_flat(terrain_flat),
        .proj_x(proj_x),
        .proj_y(proj_y),
        .proj_active(proj_active),
        .hit(hit_flag),
        .damage(damage)
    );

    // -------------------------------------------------------
    // Pixel rendering
    // -------------------------------------------------------
    render u_render (
        .px_x(px_x),
        .px_y(px_y),
        .terrain_flat(terrain_flat),
        .p0_x(p0_x), .p0_y(p0_y),
        .p1_x(p1_x), .p1_y(p1_y),
        .hp0(hp0), .hp1(hp1),
        .proj_x(proj_x), .proj_y(proj_y),
        .proj_active(proj_active),
        .turn(turn),
        .angle(angle),
        .power(power),
        .energy(energy),
        .phase(phase),
        .game_over(game_over),
        .winner(winner),
        .colour(oled_colour)
    );

    // -------------------------------------------------------
    // 7-segment: show angle ones digit
    // -------------------------------------------------------
    reg [6:0] seg_pattern;
    wire [3:0] angle_ones = angle % 10;

    always @(*) begin
        case (angle_ones)
            4'd0: seg_pattern = 7'b1000000;
            4'd1: seg_pattern = 7'b1111001;
            4'd2: seg_pattern = 7'b0100100;
            4'd3: seg_pattern = 7'b0110000;
            4'd4: seg_pattern = 7'b0011001;
            4'd5: seg_pattern = 7'b0010010;
            4'd6: seg_pattern = 7'b0000010;
            4'd7: seg_pattern = 7'b1111000;
            4'd8: seg_pattern = 7'b0000000;
            4'd9: seg_pattern = 7'b0010000;
            default: seg_pattern = 7'b1111111;
        endcase
    end

    assign seg = {1'b1, seg_pattern};  // dp off
    assign an  = 4'b1110;              // rightmost digit

    // -------------------------------------------------------
    // Debug LEDs
    // -------------------------------------------------------
    assign led[2:0]   = phase;
    assign led[3]     = turn;
    assign led[4]     = fire_trigger;
    assign led[5]     = proj_active;
    assign led[6]     = hit_flag;
    assign led[7]     = game_over;
    assign led[11:8]  = energy[3:0];
    assign led[15:12] = skill_id;

endmodule
