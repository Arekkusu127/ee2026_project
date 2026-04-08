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
    input clk_100MHz,
    input rst,
    input [15:0] sw,
    input btnU, btnD, btnL, btnR, btnC,
    output [15:0] led,
    output [6:0] seg,
    output [3:0] an,

    // OLED SPI pins
    output oled_cs,
    output oled_sdin,
    output oled_sclk,
    output oled_d_cn,
    output oled_resn,
    output oled_vccen,
    output oled_pmoden
);

    // ============================================================
    // Clock enables
    // ============================================================
    wire game_tick;
    wire anim_tick;

    clk_divider game_tick_gen (
        .clk(clk_100MHz),
        .divisor(32'd10_000_000),
        .tick(game_tick)
    );

    clk_divider anim_tick_gen (
        .clk(clk_100MHz),
        .divisor(32'd3_333_333),
        .tick(anim_tick)
    );

    // OLED 6.25 MHz clock
    reg [3:0] oled_div = 0;
    always @(posedge clk_100MHz) oled_div <= oled_div + 1;
    wire clk_oled = oled_div[3];

    // ============================================================
    // Terrain
    // ============================================================
    wire [5:0] terrain [0:95];

    map_generation map_gen (
        .clk(clk_100MHz),
        .rst(rst),
        .terrain(terrain)
    );

    // ============================================================
    // Input: angle / power
    // ============================================================
    reg [7:0] angle_reg = 8'd45;
    reg [7:0] power_reg = 8'd50;

    always @(posedge clk_100MHz or posedge rst) begin
        if (rst) begin
            angle_reg <= 8'd45;
            power_reg <= 8'd50;
        end else if (game_tick) begin
            if (btnU && angle_reg < 8'd90)  angle_reg <= angle_reg + 1;
            if (btnD && angle_reg > 8'd0)   angle_reg <= angle_reg - 1;
            if (btnR && power_reg < 8'd100) power_reg <= power_reg + 1;
            if (btnL && power_reg > 8'd0)   power_reg <= power_reg - 1;
        end
    end

    // ============================================================
    // Game state wires
    // ============================================================
    wire [2:0]  game_phase;
    wire        current_player;
    wire [7:0]  p_hp     [0:1];
    wire [4:0]  p_energy [0:1];
    wire [4:0]  p_shield [0:1];
    wire [7:0]  p_x      [0:1];
    wire [7:0]  p_y      [0:1];
    wire [7:0]  e_hp [0:3];
    wire [7:0]  e_x  [0:3];
    wire [7:0]  e_y  [0:3];
    wire        game_over_flag;
    wire        winner_id;
    wire [4:0]  current_energy;
    wire        fire_trigger;

    wire        hit_flag;
    wire [1:0]  hit_enemy_index;
    wire [5:0]  damage_to_enemy [0:3];

    wire        cast_accepted;
    wire        spawn_pulse;
    wire [4:0]  proj_energy_cost;
    wire        can_cast;
    wire [2:0]  proj_kind;
    wire [7:0]  proj_damage;
    wire        proj_effect_shield;
    wire [4:0]  proj_shield_hp;
    wire        proj_effect_heal;
    wire [4:0]  proj_heal_hp;

    wire [7:0]  proj_y [0:95];
    wire [7:0]  impact_x, impact_y;
    wire [7:0]  impact2_x, impact2_y;
    wire [7:0]  hit_x, hit_y;

    // Animation done
    reg animation_done_reg;
    always @(posedge clk_100MHz or posedge rst) begin
        if (rst)
            animation_done_reg <= 0;
        else if (game_phase == 3'd3 && (hit_flag || impact_x != 0))
            animation_done_reg <= 1;
        else if (game_phase != 3'd3)
            animation_done_reg <= 0;
    end

    game_state gs (
        .clk(clk_100MHz), .rst(rst),
        .fire_btn(btnC),
        .angle_input(angle_reg), .power_input(power_reg),
        .hit_flag(hit_flag), .hit_enemy_index(hit_enemy_index),
        .hit_damage(damage_to_enemy[hit_enemy_index]),
        .cast_accepted(cast_accepted), .spawn_pulse(spawn_pulse),
        .energy_cost_in(proj_energy_cost),
        .effect_shield_in(proj_effect_shield), .shield_hp_in(proj_shield_hp),
        .effect_heal_in(proj_effect_heal), .heal_hp_in(proj_heal_hp),
        .animation_done(animation_done_reg),
        .phase(game_phase), .current_player(current_player),
        .player_hp(p_hp), .player_energy(p_energy), .player_shield(p_shield),
        .player_x(p_x), .player_y(p_y),
        .enemy_hp(e_hp), .enemy_x(e_x), .enemy_y(e_y),
        .game_over(game_over_flag), .winner(winner_id),
        .current_angle(), .current_power(),
        .current_energy(current_energy), .fire_trigger(fire_trigger)
    );

    // ============================================================
    // Projectile controller
    // ============================================================
    wire signed [8:0]  proj_angle_offset;
    wire [3:0]         proj_speed_scale;
    wire signed [18:0] proj_gravity;
    wire proj_straight, proj_ign_terrain, proj_ign_entities;
    wire proj_pierce_ent, proj_pierce_terr, proj_bounce_terr;
    wire proj_explode;
    wire [4:0] proj_aoe_r;
    wire [7:0] proj_aoe_dmg;
    wire proj_from_sky;
    wire signed [7:0] proj_spawn_xoff;
    wire [5:0] proj_spawn_ystart;
    wire proj_fire_zone, proj_grav_pull, proj_chain_light;
    wire [4:0] proj_energy_after;

    projectile proj_ctrl (
        .clk(clk_100MHz), .rst(rst),
        .step_en(game_tick),
        .cast_req(fire_trigger),
        .impact_trigger(impact_x != 0),
        .sw(sw), .energy_in(current_energy),
        .cast_accepted(cast_accepted), .spawn_pulse(spawn_pulse),
        .energy_after(proj_energy_after), .can_cast(can_cast),
        .energy_cost(proj_energy_cost),
        .projectile_kind(proj_kind),
        .angle_offset_deg(proj_angle_offset),
        .damage(proj_damage),
        .speed_scale_q2(proj_speed_scale),
        .gravity_q10(proj_gravity),
        .straight_line(proj_straight),
        .ignore_terrain(proj_ign_terrain),
        .ignore_entities(proj_ign_entities),
        .pierce_entities_once(proj_pierce_ent),
        .pierce_terrain_once(proj_pierce_terr),
        .bounce_terrain_once(proj_bounce_terr),
        .explode_on_impact(proj_explode),
        .aoe_radius(proj_aoe_r), .aoe_base_damage(proj_aoe_dmg),
        .spawn_from_sky(proj_from_sky),
        .spawn_x_offset(proj_spawn_xoff),
        .spawn_y_start(proj_spawn_ystart),
        .effect_shield(proj_effect_shield), .shield_hp(proj_shield_hp),
        .effect_heal(proj_effect_heal), .heal_hp(proj_heal_hp),
        .effect_fire_zone(proj_fire_zone),
        .effect_gravity_pull(proj_grav_pull),
        .effect_chain_lightning(proj_chain_light)
    );

    // ============================================================
    // Entity packing → attack module
    // ============================================================
    wire [45:0] player_entity;
    assign player_entity = {
        2'd0,
        p_hp[current_player][5:0],
        6'd5, 6'd10, 6'd0,
        p_x[current_player],
        p_y[current_player],
        4'd3, 4'd3
    };

    wire [45:0] enemy_entity [0:3];
    genvar ei;
    generate
        for (ei = 0; ei < 4; ei = ei + 1) begin : ep
            assign enemy_entity[ei] = {
                2'd1, e_hp[ei][5:0],
                6'd3, 6'd8, 6'd0,
                e_x[ei], e_y[ei],
                4'd2, 4'd2
            };
        end
    endgenerate

    wire signed [7:0] attack_offset;
    assign attack_offset = $signed({1'b0, angle_reg[6:0]}) - 8'sd45;

    attack atk (
        .clk(clk_100MHz),
        .offset_num(attack_offset),
        .projectile_type(proj_kind),
        .dmg(proj_damage[5:0]),
        .player_data(player_entity),
        .enemy_data(enemy_entity),
        .terrain(terrain),
        .projectile_y(proj_y),
        .impact_x(impact_x), .impact_y(impact_y),
        .impact2_x(impact2_x), .impact2_y(impact2_y),
        .hit_flag(hit_flag), .hit_enemy_index(hit_enemy_index),
        .hit_x(hit_x), .hit_y(hit_y),
        .damage_to_enemy(damage_to_enemy)
    );

    // ============================================================
    // OLED Display (96x64, RGB565)
    // ============================================================
    localparam PIXEL_COUNT_WIDTH = $clog2(96 * 64);

    wire frame_begin, sending_pixels, sample_pixel;
    wire [PIXEL_COUNT_WIDTH-1:0] pixel_index;
    reg  [15:0] pixel_data;

    Oled_Display #(
        .ClkFreq(6250000)
    ) oled (
        .clk(clk_oled),
        .reset(rst),
        .frame_begin(frame_begin),
        .sending_pixels(sending_pixels),
        .sample_pixel(sample_pixel),
        .pixel_index(pixel_index),
        .pixel_data(pixel_data),
        .cs(oled_cs),
        .sdin(oled_sdin),
        .sclk(oled_sclk),
        .d_cn(oled_d_cn),
        .resn(oled_resn),
        .vccen(oled_vccen),
        .pmoden(oled_pmoden)
    );

    // Pixel (x,y) tracking — avoids division by 96
    reg [6:0] px_x;
    reg [5:0] px_y;
    reg [PIXEL_COUNT_WIDTH-1:0] prev_pixel_index;

    always @(posedge clk_oled or posedge rst) begin
        if (rst) begin
            px_x <= 0; px_y <= 0; prev_pixel_index <= 0;
        end else if (sample_pixel) begin
            if (pixel_index == 0) begin
                px_x <= 0; px_y <= 0;
            end else if (pixel_index != prev_pixel_index) begin
                if (px_x == 7'd95) begin
                    px_x <= 0;
                    px_y <= px_y + 1;
                end else begin
                    px_x <= px_x + 1;
                end
            end
            prev_pixel_index <= pixel_index;
        end
    end

    // RGB565 colors
    localparam [15:0] C_SKY      = 16'b01010_100000_11111;
    localparam [15:0] C_TERRAIN  = 16'b00010_101000_00010;
    localparam [15:0] C_P0       = 16'b00010_000100_11111;
    localparam [15:0] C_P1       = 16'b11111_000100_00010;
    localparam [15:0] C_ENEMY    = 16'b11111_111110_00000;
    localparam [15:0] C_PROJ     = 16'b11111_111111_11111;
    localparam [15:0] C_HP_FILL  = 16'b11111_000000_00000;
    localparam [15:0] C_HP_EMPTY = 16'b01000_010000_01000;
    localparam [15:0] C_BLACK    = 16'b00000_000000_00000;
    localparam [15:0] C_ORANGE   = 16'b11111_100000_00000;
    localparam [15:0] C_GREEN    = 16'b00000_111111_00000;
    localparam [15:0] C_YELLOW   = 16'b11111_111111_00000;

    // Hit tests
    wire at_p0 = (p_hp[0] > 0) &&
        (px_x >= p_x[0] - 3) && (px_x <= p_x[0] + 3) &&
        (px_y >= p_y[0] - 3) && (px_y <= p_y[0] + 3);
    wire at_p1 = (p_hp[1] > 0) &&
        (px_x >= p_x[1] - 3) && (px_x <= p_x[1] + 3) &&
        (px_y >= p_y[1] - 3) && (px_y <= p_y[1] + 3);
    wire at_e0 = (e_hp[0] > 0) &&
        (px_x >= e_x[0] - 2) && (px_x <= e_x[0] + 2) &&
        (px_y >= e_y[0] - 2) && (px_y <= e_y[0] + 2);
    wire at_e1 = (e_hp[1] > 0) &&
        (px_x >= e_x[1] - 2) && (px_x <= e_x[1] + 2) &&
        (px_y >= e_y[1] - 2) && (px_y <= e_y[1] + 2);
    wire at_terr = (px_x < 96) && (px_y >= terrain[px_x]);
    wire at_proj = (px_x < 96) && (proj_y[px_x] != 8'd65) &&
        (px_y == proj_y[px_x][5:0]);

    // HP bar (y=62..63): hp*41>>6 ≈ hp*96/150
    wire [13:0] hp_prod = p_hp[current_player] * 14'd41;
    wire [7:0]  hp_len  = hp_prod[13:6];
    wire in_hp      = (px_y >= 62);
    wire hp_filled  = (px_x < hp_len);

    // Angle bar (y=0)
    wire [7:0] angle_len = angle_reg + (angle_reg >> 4);
    wire in_angle   = (px_y == 0);
    wire angle_fill = (px_x < angle_len);

    // Power bar (y=1)
    wire in_power   = (px_y == 1);
    wire power_fill = (px_x < power_reg);

    // Energy dots (y=2)
    wire in_energy  = (px_y == 2);
    wire energy_fill = (px_x < p_energy[current_player]);

    // Turn indicator (3x3 top-left)
    wire turn_ind = (px_x < 3) && (px_y < 3);

    // Game over overlay
    wire go_pixel = game_over_flag &&
        (px_y >= 25) && (px_y <= 38) && (px_x >= 20) && (px_x <= 75);

    // Priority pixel mux
    always @(*) begin
        if (go_pixel)
            pixel_data = (winner_id == 0) ? C_P0 : C_P1;
        else if (turn_ind)
            pixel_data = (current_player == 0) ? C_P0 : C_P1;
        else if (in_angle)
            pixel_data = angle_fill ? C_ORANGE : C_BLACK;
        else if (in_power)
            pixel_data = power_fill ? C_GREEN : C_BLACK;
        else if (in_energy)
            pixel_data = energy_fill ? C_YELLOW : C_BLACK;
        else if (in_hp)
            pixel_data = hp_filled ? C_HP_FILL : C_HP_EMPTY;
        else if (at_p0)
            pixel_data = C_P0;
        else if (at_p1)
            pixel_data = C_P1;
        else if (at_e0 || at_e1)
            pixel_data = C_ENEMY;
        else if (at_proj)
            pixel_data = C_PROJ;
        else if (at_terr)
            pixel_data = C_TERRAIN;
        else
            pixel_data = C_SKY;
    end

    // ============================================================
    // LEDs
    // ============================================================
    assign led[0]     = can_cast;
    assign led[1]     = hit_flag;
    assign led[2]     = game_over_flag;
    assign led[3]     = current_player;
    assign led[6:4]   = game_phase;
    assign led[7]     = 0;
    assign led[12:8]  = p_energy[current_player];
    assign led[15:13] = proj_kind;

    // ============================================================
    // 7-segment: angle ones digit
    // ============================================================
    assign an = 4'b1110;
    reg [6:0] seg_display;
    always @(*) begin
        case (angle_reg % 10)
            0: seg_display = 7'b1000000;
            1: seg_display = 7'b1111001;
            2: seg_display = 7'b0100100;
            3: seg_display = 7'b0110000;
            4: seg_display = 7'b0011001;
            5: seg_display = 7'b0010010;
            6: seg_display = 7'b0000010;
            7: seg_display = 7'b1111000;
            8: seg_display = 7'b0000000;
            9: seg_display = 7'b0010000;
            default: seg_display = 7'b1111111;
        endcase
    end
    assign seg = seg_display;

endmodule


