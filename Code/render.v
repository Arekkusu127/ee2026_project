`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2026 18:42:48
// Design Name: 
// Module Name: render
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

module render(
    input         CLOCK,
    input         frame_begin,
    input [6:0]  explosion_center_x,
    input [5:0]  explosion_center_y,
    input        explosion_pending,
    input boss_attack_active,
    input [6:0] boss_attack_x,
    input  [6:0]  pix_x,
    input  [5:0]  pix_y,
    input         game_started,
    input  [2:0]  game_phase,
    input  [45:0] player_entity,
    input  [6:0]  player_angle,
    input  [3:0]  player_power,
    input  [3:0]  player_energy,
    input         current_round,
    input  [45:0] enemy_entity_0,
    input  [45:0] enemy_entity_1,
    input  [45:0] enemy_entity_2,
    input  [2:0]  enemy_alive,
    input  [6:0]  slime0_x,
    input  [6:0]  slime1_x,
    input  [5:0]  slime_y,
    input         proj_active,
    input  [6:0]  proj_x,
    input  [5:0]  proj_y,
    input  [5:0]  terrain_height,
    input         victory,
    input         defeat,
    input         trail_pixel,
    input         arc_pixel,
    input  [6:0]  reticle_x,
    input  [5:0]  reticle_y,
    output reg [15:0] pixel_data
);

    // Game phases
    localparam PH_AIM  = 3'd1;
    localparam PH_MOVE = 3'd7;
    localparam PH_GAMEOVER = 3'd6;

    // Entity field extraction
    wire [6:0] px  = player_entity[19:13];
    wire [5:0] py  = player_entity[12:7];
    wire [3:0] phw = player_entity[6:3];
    wire [2:0] phh = player_entity[2:0];
    wire [5:0] php = player_entity[43:38];

    wire [6:0] ex0 = enemy_entity_0[19:13];
    wire [5:0] ey0 = enemy_entity_0[12:7];
    wire [3:0] ehw0 = enemy_entity_0[6:3];
    wire [2:0] ehh0 = enemy_entity_0[2:0];
    wire [5:0] ehp0 = enemy_entity_0[43:38];
    wire [1:0] et0  = enemy_entity_0[45:44];

    wire [6:0] ex1 = enemy_entity_1[19:13];
    wire [5:0] ey1 = enemy_entity_1[12:7];
    wire [3:0] ehw1 = enemy_entity_1[6:3];
    wire [2:0] ehh1 = enemy_entity_1[2:0];
    wire [5:0] ehp1 = enemy_entity_1[43:38];

    wire [6:0] ex2 = enemy_entity_2[19:13];
    wire [5:0] ey2 = enemy_entity_2[12:7];
    wire [3:0] ehw2 = enemy_entity_2[6:3];
    wire [2:0] ehh2 = enemy_entity_2[2:0];
    wire [5:0] ehp2 = enemy_entity_2[43:38];
    wire boss_phase  = current_round && enemy_alive[0] && (enemy_entity_0 != 46'd0);
    wire slime_phase = !current_round;

    localparam [6:0] SLIME_W = 7'd14;
    localparam [5:0] SLIME_H = 6'd9;

    // Colors (RGB565)
    localparam C_PLAYER       = 16'hFFE0;
    localparam C_MINION       = 16'hF800;
    localparam C_MINION_DEAD  = 16'h8410;
    localparam C_BOSS         = 16'hF81F;
    localparam C_BOSS_DEAD    = 16'h8410;
    localparam C_PROJ         = 16'hFFFF;
    localparam C_HP_FILL      = 16'h07E0;
    localparam C_HP_EMPTY     = 16'h4208;
    localparam C_RETICLE      = 16'hF800;  // Red crosshair
    localparam C_ARC_PREVIEW  = 16'h07FF;  // Cyan dotted arc
    localparam C_VICTORY      = 16'hFFE0;
    localparam C_DEFEAT       = 16'hF800;
    localparam C_TRAIL        = 16'h7BEF;


    // ============================================================
    // BACKGROUND INTEGRATION
    // ============================================================
    wire [15:0] bg_pixel;

    background bg_inst (
        .CLOCK(CLOCK),
        .game_started(game_started),
        .frame_begin(frame_begin),
        .hcount(pix_x),
        .vcount(pix_y),
        .pixel(bg_pixel)
    );
    
    wire [15:0] victory_pixel;
    victory victory_inst (
        .hcount(pix_x),
        .vcount(pix_y),
        .pixel(victory_pixel)
    );
    
    wire [15:0] defeat_pixel;
    defeat defeat_inst (
        .hcount(pix_x),
        .vcount(pix_y),
        .pixel(defeat_pixel)
    );

    // ============================================================
    // RETICLE CROSSHAIR (replaces aim circle)
    // ============================================================
    // Draw a small crosshair at reticle position during AIM phase
    wire reticle_h_bar = (game_phase == PH_AIM) &&
        (pix_y == reticle_y) &&
        (pix_x >= reticle_x - 7'd2) && (pix_x <= reticle_x + 7'd2) &&
        (reticle_x >= 7'd2) && (reticle_x <= 7'd93);

    wire reticle_v_bar = (game_phase == PH_AIM) &&
        (pix_x == reticle_x) &&
        (pix_y >= reticle_y - 6'd2) && (pix_y <= reticle_y + 6'd2) &&
        (reticle_y >= 6'd2) && (reticle_y <= 6'd61);

    wire reticle_hit = reticle_h_bar || reticle_v_bar;

    // ============================================================
    // ARC PREVIEW (precalculated dotted arc during AIM)
    // ============================================================
    wire arc_dotted = arc_pixel && (game_phase == PH_AIM) && ((pix_x[0] ^ pix_y[0]) == 1'b0);

    // ============================================================
    // HP BARS
    // ============================================================
    wire signed [7:0] php_bar_top = $signed({2'b0, py}) - $signed({5'b0, phh}) - 8'sd7;
    wire signed [7:0] php_bar_bot = $signed({2'b0, py}) - $signed({5'b0, phh}) - 8'sd3;
    // Player HP bar - horizontal bar floating above the girl sprite
    wire [6:0] player_bar_left  = girl_left + 7'd5;
    wire [6:0] player_bar_right = girl_left + 7'd24;   // 20 pixels wide
    wire [5:0] player_bar_y0    = (girl_top >= 6'd4) ? (girl_top - 6'd4) : 6'd0;
    wire [5:0] player_bar_y1    = (girl_top >= 6'd3) ? (girl_top - 6'd3) : 6'd0;

    wire player_hp_bar_region =
        (pix_x >= player_bar_left) && (pix_x <= player_bar_right) &&
        (pix_y >= player_bar_y0)   && (pix_y <= player_bar_y1);

    wire [4:0] player_hp_fill_w =
        (php >= 6'd50) ? 5'd20 :
        (php >= 6'd40) ? 5'd16 :
        (php >= 6'd30) ? 5'd12 :
        (php >= 6'd20) ? 5'd8  :
        (php >= 6'd10) ? 5'd4  : 5'd0;

    wire player_hp_filled =
        player_hp_bar_region &&
        (pix_x < player_bar_left + player_hp_fill_w);

    // Boss HP bar (round 2)
    wire [6:0] boss_bar_left  = boss_left + 7'd8;
    wire [6:0] boss_bar_right = boss_left + 7'd31;   // 24 pixels wide
    wire [5:0] boss_bar_y0    = (boss_top >= 6'd4) ? (boss_top - 6'd4) : 6'd0;
    wire [5:0] boss_bar_y1    = (boss_top >= 6'd3) ? (boss_top - 6'd3) : 6'd0;

    wire boss_hp_bar_region =
        boss_phase &&
        (pix_x >= boss_bar_left) && (pix_x <= boss_bar_right) &&
        (pix_y >= boss_bar_y0)   && (pix_y <= boss_bar_y1);

    wire [4:0] boss_hp_fill_w =
        (ehp0 >= 6'd50) ? 5'd24 :
        (ehp0 >= 6'd40) ? 5'd19 :
        (ehp0 >= 6'd30) ? 5'd14 :
        (ehp0 >= 6'd20) ? 5'd10 :
        (ehp0 >= 6'd10) ? 5'd5  : 5'd0;

    wire boss_hp_filled =
        boss_hp_bar_region &&
        (pix_x < boss_bar_left + boss_hp_fill_w);

    // Slime 0 HP bar (horizontal)
    wire slime0_bar_region = slime_phase && enemy_alive[0] &&
                             (slime_y >= 6'd2) &&
                             (pix_y == slime_y - 6'd2) &&
                             (pix_x >= slime0_x) && (pix_x < slime0_x + SLIME_W);

    wire [3:0] slime0_fill_w = (ehp0 >= 6'd50) ? 4'd14 :
                               (ehp0 >= 6'd40) ? 4'd11 :
                               (ehp0 >= 6'd30) ? 4'd8  :
                               (ehp0 >= 6'd20) ? 4'd6  :
                               (ehp0 >= 6'd10) ? 4'd3  : 4'd0;

    wire slime0_hp_filled = slime0_bar_region && (pix_x < slime0_x + slime0_fill_w);

    // Slime 1 HP bar (horizontal)
    wire slime1_bar_region = slime_phase && enemy_alive[1] &&
                             (slime_y >= 6'd2) &&
                             (pix_y == slime_y - 6'd2) &&
                             (pix_x >= slime1_x) && (pix_x < slime1_x + SLIME_W);

    wire [3:0] slime1_fill_w = (ehp1 >= 6'd50) ? 4'd14 :
                               (ehp1 >= 6'd40) ? 4'd11 :
                               (ehp1 >= 6'd30) ? 4'd8  :
                               (ehp1 >= 6'd20) ? 4'd6  :
                               (ehp1 >= 6'd10) ? 4'd3  : 4'd0;

    wire slime1_hp_filled = slime1_bar_region && (pix_x < slime1_x + slime1_fill_w);

    // ============================================================
    // ENTITY SPRITES
    // ============================================================
    wire [6:0] girl_left = (px >= 7'd15) ? (px - 7'd15) : 7'd0;
    wire [5:0] girl_top  = (py >= 6'd15) ? (py - 6'd15) : 6'd0;
    
    wire [6:0] local_xg_full = pix_x - girl_left;
    wire [5:0] local_yg_full = pix_y - girl_top;
    wire [4:0] local_xg = local_xg_full[4:0];
    wire [4:0] local_yg = local_yg_full[4:0];
    
    wire in_girl = (pix_x >= girl_left) && (pix_x < girl_left + 7'd30) && (pix_y >= girl_top) && (pix_y < girl_top + 6'd30);
    wire [15:0] girl_pixel;
    wire girl_vis;

    girl girl_inst(
        .game_started(game_started),
        .x_pos(local_xg),
        .y_pos(local_yg),
        .pixel(girl_pixel),
        .visible(girl_vis)
    );

    

    // fixed boss sprite position
    wire [6:0] boss_left = 7'd55;
    wire [5:0] boss_top  = 6'd7;

    wire in_boss = boss_phase &&
                (pix_x >= boss_left) && (pix_x < boss_left + 7'd40) &&
                (pix_y >= boss_top)  && (pix_y < boss_top + 6'd50);

    wire [5:0] local_xb = pix_x[5:0] - boss_left[5:0];
    wire [5:0] local_yb = pix_y - boss_top;

    wire [15:0] boss_pixel;
    wire boss_vis;

    boss boss_inst(
        .frame_begin(frame_begin),
        .x_pos(local_xb),
        .y_pos(local_yb),
        .pixel(boss_pixel),
        .visible(boss_vis)
    );

    // full-screen vertical red beam
    wire boss_beam_hit = boss_attack_active &&
                        (pix_x >= boss_attack_x) &&
                        (pix_x <= boss_attack_x + 7'd5); // 6 pixels wide

    wire in_slime0 = slime_phase && enemy_alive[0] &&
                     (pix_x >= slime0_x) && (pix_x < slime0_x + 7'd14) &&
                     (pix_y >= slime_y ) && (pix_y < slime_y  + 6'd9);

    wire in_slime1 = slime_phase && enemy_alive[1] &&
                     (pix_x >= slime1_x) && (pix_x < slime1_x + 7'd14) &&
                     (pix_y >= slime_y ) && (pix_y < slime_y  + 6'd9);

    wire [6:0] local_x0_full = pix_x - slime0_x;
    wire [5:0] local_y0_full = pix_y - slime_y;
    wire [6:0] local_x1_full = pix_x - slime1_x;
    wire [5:0] local_y1_full = pix_y - slime_y;

    wire [3:0] local_x0 = local_x0_full[3:0];
    wire [3:0] local_y0 = local_y0_full[3:0];
    wire [3:0] local_x1 = local_x1_full[3:0];
    wire [3:0] local_y1 = local_y1_full[3:0];

    wire [15:0] slime0_pixel, slime1_pixel;
    wire slime0_vis, slime1_vis;

    slime0 slime0_inst(
        .frame_begin(frame_begin),
        .x_pos(local_x0),
        .y_pos(local_y0),
        .pixel(slime0_pixel),
        .visible(slime0_vis)
    );

    slime1 slime1_inst(
        .frame_begin(frame_begin),
        .x_pos(local_x1),
        .y_pos(local_y1),
        .pixel(slime1_pixel),
        .visible(slime1_vis)
    );  


    wire [6:0] bomb_left = (explosion_center_x >= 7'd3) ? (explosion_center_x - 7'd3) : 7'd0;
    wire [5:0] bomb_top  = (explosion_center_y >= 6'd3) ? (explosion_center_y - 6'd3) : 6'd0;

    wire in_bomb = (pix_x >= bomb_left) && (pix_x < bomb_left + 7'd6) &&
                   (pix_y >= bomb_top ) && (pix_y < bomb_top  + 6'd6);

    wire [2:0] bomb_local_x = (pix_x - bomb_left)[2:0];
    wire [2:0] bomb_local_y = (pix_y - bomb_top )[2:0];

    wire [15:0] bomb_pixel;
    wire bomb_vis;

    bomb bomb_inst(
        .CLOCK(CLOCK),
        .rst(!game_started),
        .frame_begin(frame_begin),
        .explosion_pending(explosion_pending),
        .x_pos(bomb_local_x),
        .y_pos(bomb_local_y),
        .pixel(bomb_pixel),
        .visible(bomb_vis)
    );


    wire proj_hit = proj_active &&
                    (pix_x >= proj_x) && (pix_x <= proj_x + 7'd1) &&
                    (pix_y >= proj_y) && (pix_y <= proj_y + 6'd1);

    //wire trail_dotted = trail_pixel && ((pix_x[0] ^ pix_y[0]) == 1'b0);
    wire trail_dotted = trail_pixel;
    // NO terrain rendering - terrain_hit removed

    wire gameover_banner = (game_phase == PH_GAMEOVER);

    // ============================================================
    // PRIORITY MUX
    // ============================================================
    always @(*) begin
        if (!game_started) begin
            pixel_data = bg_pixel;
        end
        else if (gameover_banner) begin
            pixel_data = victory ? victory_pixel : defeat_pixel;
        end
        else if (boss_beam_hit) begin
            pixel_data = 16'hF800;
        end
        else if (reticle_hit) begin
            pixel_data = C_RETICLE;
        end
        else if (arc_dotted) begin
            pixel_data = C_ARC_PREVIEW;
        end
        else if (proj_hit) begin
            pixel_data = C_PROJ;
        end
        else if (in_bomb && bomb_vis) begin
            pixel_data = bomb_pixel;
        end
        else if (player_hp_filled) begin
            pixel_data = C_HP_FILL;
        end
        else if (boss_hp_filled || slime0_hp_filled || slime1_hp_filled) begin
            pixel_data = C_MINION;
        end
        else if (player_hp_bar_region || boss_hp_bar_region || slime0_bar_region || slime1_bar_region) begin
            pixel_data = C_HP_EMPTY;
        end
        else if (in_girl && girl_vis) begin
            pixel_data = girl_pixel;
        end
        else if (in_boss && boss_vis) begin
            pixel_data = boss_pixel;
        end
        else if (in_slime0 && slime0_vis) begin
            pixel_data = slime0_pixel;
        end
        else if (in_slime1 && slime1_vis) begin
            pixel_data = slime1_pixel;
        end
        else if (trail_dotted) begin
            pixel_data = C_TRAIL;
        end
        else begin
            pixel_data = bg_pixel;
        end
    end

endmodule
