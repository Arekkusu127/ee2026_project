`timescale 1ns / 1ps
module slime0(
    input frame_begin,
    input [3:0] x_pos,
    input [3:0] y_pos,
    output [15:0] pixel,
    output visible
);
    reg [15:0] rom [0:125];
    initial begin
        `ifdef SYNTHESIS
            $readmemb("../../FDP.srcs/sources_1/new/slime0.bin", rom);
        `else
            $readmemb("../../../../FDP.srcs/sources_1/new/slime0.bin", rom);
        `endif
    end

    wire [6:0] addr = y_pos * 14 + {3'd0, x_pos};
    assign pixel = rom[addr];
    assign visible = (pixel != 16'hffff);
endmodule

module slime1(
    input frame_begin,
    input [3:0] x_pos,
    input [3:0] y_pos,
    output [15:0] pixel,
    output visible
);
    reg [15:0] rom [0:125];
    initial begin
        `ifdef SYNTHESIS
            $readmemb("../../FDP.srcs/sources_1/new/slime1.bin", rom);
        `else
            $readmemb("../../../../FDP.srcs/sources_1/new/slime1.bin", rom);
        `endif
    end

    wire [6:0] addr = y_pos * 14 + {3'd0, x_pos};
    assign pixel = rom[addr];
    assign visible = (pixel != 16'hffff);
endmodule

module boss(
    input frame_begin,
    input [5:0] x_pos,
    input [5:0] y_pos,
    output  [15:0] pixel,
    output visible
);
    reg [15:0] rom [0:1999];
    initial begin
        `ifdef SYNTHESIS
            $readmemb("../../FDP.srcs/sources_1/new/boss.bin", rom);
        `else
            $readmemb("../../../../FDP.srcs/sources_1/new/boss.bin", rom);
        `endif
    end
    wire [10:0] addr = y_pos * 40 + x_pos; // 40 pixels per row
    assign pixel = rom[addr];
    wire [4:0] r = pixel[15:11];
    wire [5:0] g = pixel[10:5];
    wire [4:0] b = pixel[4:0];
    assign visible = !( (r >= 28) && (g >= 45) && (g <= 55) && (b >= 28) );

endmodule

module girl(
    input game_started,
    input [4:0] x_pos,
    input [4:0] y_pos,
    output  [15:0] pixel,
    output visible
);
    reg [15:0] rom [0:899];  // 900 pixels, each 16 bits
    initial begin
    `ifdef SYNTHESIS
        $readmemb("../../FDP.srcs/sources_1/new/girl.bin", rom);
    `else
        $readmemb("../../../../FDP.srcs/sources_1/new/girl.bin", rom);
    `endif
    end
    wire [9:0] addr = y_pos * 30 + x_pos; // 30 pixels per row
    assign pixel = rom[addr];
    wire [4:0] r = pixel[15:11];
    wire [5:0] g = pixel[10:5];
    wire [4:0] b = pixel[4:0];
    assign visible = !( (r >= 28) && (g >= 45) && (g <= 55) && (b >= 28) );
endmodule

module background(
    input CLOCK,
    input game_started,
    input frame_begin,
    input  [6:0] hcount,
    input  [5:0] vcount,
    output [15:0] pixel
);
    reg [15:0] rom0 [0:6143];
    reg [15:0] rom1 [0:6143];
    reg [15:0] rom2 [0:6143];

    initial begin
    `ifdef SYNTHESIS
        $readmemb("../../FDP.srcs/sources_1/new/bg_rom0.bin", rom0);
        $readmemb("../../FDP.srcs/sources_1/new/bg_rom1.bin", rom1);
        $readmemb("../../FDP.srcs/sources_1/new/bg_rom2.bin", rom2);
    `else
        $readmemb("../../../../FDP.srcs/sources_1/new/bg_rom0.bin", rom0);
        $readmemb("../../../../FDP.srcs/sources_1/new/bg_rom1.bin", rom1);
        $readmemb("../../../../FDP.srcs/sources_1/new/bg_rom2.bin", rom2);
    `endif
    end

    wire [12:0] addr = ({vcount, 6'd0} + {vcount, 5'd0}) + {6'd0, hcount};

    reg [7:0] frame_cnt;
    reg bg_sel;

    always @(posedge CLOCK) begin
        if (frame_begin) begin
            if (frame_cnt == 8'd202) begin
                frame_cnt <= 0;
                bg_sel <= ~bg_sel;
            end else begin
                frame_cnt <= frame_cnt + 1;
            end
        end    
    end

    wire [15:0] auto_pixel = bg_sel ? rom1[addr] : rom0[addr]; 
    assign pixel = game_started ? rom2[addr] : auto_pixel;
endmodule

module render(
    input         CLOCK,
    input         frame_begin,
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
    //localparam C_SLIME        = 16'h07E0;

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
    wire signed [7:0] boss_bar_top = $signed({2'b0, ey0}) - $signed({5'b0, ehh0}) - 8'sd7;
    wire signed [7:0] boss_bar_bot = $signed({2'b0, ey0}) - $signed({5'b0, ehh0}) - 8'sd3;
    wire boss_hp_bar_region = boss_phase &&
        (pix_x == ex0 || pix_x == ex0 - 7'd1) &&
        ($signed({2'b0, pix_y}) >= boss_bar_top) &&
        ($signed({2'b0, pix_y}) <= boss_bar_bot) &&
        (boss_bar_top >= 0);
    wire [2:0] boss_fill = (ehp0 >= 6'd50) ? 3'd5 :
                           (ehp0 >= 6'd40) ? 3'd4 :
                           (ehp0 >= 6'd30) ? 3'd3 :
                           (ehp0 >= 6'd20) ? 3'd2 :
                           (ehp0 >= 6'd10) ? 3'd1 : 3'd0;
    wire signed [7:0] boss_fill_top = boss_bar_bot - $signed({5'b0, boss_fill}) + 8'sd1;
    wire boss_hp_filled = boss_hp_bar_region && ($signed({2'b0, pix_y}) >= boss_fill_top);

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
                        (pix_x <= boss_attack_x + 7'd1);

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


    wire proj_hit = proj_active &&
                    (pix_x >= proj_x) && (pix_x <= proj_x + 7'd1) &&
                    (pix_y >= proj_y) && (pix_y <= proj_y + 6'd1);

    wire trail_dotted = trail_pixel && ((pix_x[0] ^ pix_y[0]) == 1'b0);

    // NO terrain rendering - terrain_hit removed

    wire gameover_banner = (game_phase == PH_GAMEOVER) &&
                           (pix_x >= 7'd20) && (pix_x <= 7'd75) &&
                           (pix_y >= 6'd25) && (pix_y <= 6'd38);

    // ============================================================
    // PRIORITY MUX
    // ============================================================
    always @(*) begin
        if (!game_started) begin
            pixel_data = bg_pixel;
        end
        else if (gameover_banner) begin
            pixel_data = victory ? C_VICTORY : C_DEFEAT;
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
        else if (player_hp_filled || boss_hp_filled || slime0_hp_filled || slime1_hp_filled) begin
            pixel_data = C_HP_FILL;
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
