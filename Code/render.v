`timescale 1ns / 1ps
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
    input  [6:0] hcount,      // 0-95  (7 bits)
    input  [5:0] vcount,      // 0-63  (6 bits)
    output [15:0] pixel
);
    reg [15:0] rom0 [0:6143];  // 6144 pixels, each 16 bits
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

    // Address = vcount * 96 + hcount
    // 96 = 64 + 32 = (1<<6) + (1<<5)
    wire [12:0] addr = ({vcount, 6'd0} + {vcount, 5'd0}) + {6'd0, hcount};

    reg [7:0] frame_cnt;     // 8 bits enough for up to 255 frames
    reg bg_sel;
    

    always @(posedge CLOCK) begin
        if (frame_begin) begin
            if (frame_cnt == 8'd202) begin   // 0..202 = 203 frames
                frame_cnt <= 0;
                bg_sel <= ~bg_sel;
            end else begin
                frame_cnt <= frame_cnt + 1;
            end
        end    
    end

    wire [15:0] auto_pixel = bg_sel? rom1[addr]:rom0[addr]; 
    assign pixel = game_started ? rom2[addr] : auto_pixel;

endmodule
module render(
    input         CLOCK,
    input         frame_begin,
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
    input         proj_active,
    input  [6:0]  proj_x,
    input  [5:0]  proj_y,
    input  [5:0]  terrain_height,
    input         victory,
    input         defeat,
    input         trail_pixel,
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

    // Colors (RGB565)
    localparam C_TERRAIN      = 16'h07E0;
    localparam C_PLAYER       = 16'hFFE0;
    localparam C_PLAYER_DEAD  = 16'h8410;
    localparam C_MINION       = 16'hF800;
    localparam C_MINION_DEAD  = 16'h8410;
    localparam C_BOSS         = 16'hF81F;
    localparam C_BOSS_DEAD    = 16'h8410;
    localparam C_PROJ         = 16'hFFFF;
    localparam C_HP_FILL      = 16'h07E0;
    localparam C_HP_EMPTY     = 16'h4208;
    localparam C_AIM_CIRCLE   = 16'hFFFF;
    localparam C_AIM_DOT      = 16'hF800;
    localparam C_VICTORY      = 16'hFFE0;
    localparam C_DEFEAT       = 16'hF800;
    localparam C_MENU_BG      = 16'h0000;
    localparam C_MENU_TEXT    = 16'hFFFF;
    localparam C_MENU_ACCENT  = 16'hFFE0;
    localparam C_TRAIL        = 16'h7BEF;

    // ============================================================
    // BACKGROUND INTEGRATION
    // ============================================================
    wire [15:0] bg_pixel;
    wire bg_led_unused;

    background bg_inst (
        .CLOCK(CLOCK),
        .game_started(game_started),   // standby animation when 0, gameplay bg when 1
        .frame_begin(frame_begin),
        .hcount(pix_x),
        .vcount(pix_y),
        .pixel(bg_pixel)
    );

    // ============================================================
    // START MENU
    // ============================================================
//    wire menu_border = (!game_started) && (
//        (pix_x >= 7'd10 && pix_x <= 7'd85 && (pix_y == 6'd10 || pix_y == 6'd50)) ||
//        ((pix_x == 7'd10 || pix_x == 7'd85) && pix_y >= 6'd10 && pix_y <= 6'd50)
//    );
    
//    wire menu_title = (!game_started) &&
//        (pix_x >= 7'd20 && pix_x <= 7'd75 && pix_y >= 6'd18 && pix_y <= 6'd26);
    
//    wire menu_press = (!game_started) &&
//        (pix_x >= 7'd30 && pix_x <= 7'd65 && pix_y >= 6'd35 && pix_y <= 6'd43);

//    wire menu_cross = (!game_started) && (
//        ((pix_x == 7'd48) && pix_y >= 6'd28 && pix_y <= 6'd32) ||
//        (pix_y == 6'd30 && pix_x >= 7'd46 && pix_x <= 7'd50)
//    );

    // ============================================================
    // AIMING CIRCLE
    // ============================================================
    localparam AIM_R = 30;
    localparam [15:0] AIM_R_SQ_OUT = 16'd920;
    localparam [15:0] AIM_R_SQ_IN  = 16'd841;
    
    wire signed [7:0] aim_dx = $signed({1'b0, pix_x}) - $signed({1'b0, px});
    wire signed [7:0] aim_dy = $signed({1'b0, pix_y}) - $signed({1'b0, py});
    wire [15:0] aim_dist_sq = aim_dx * aim_dx + aim_dy * aim_dy;
    
    wire aim_circle_outline = (game_phase == PH_AIM) && 
        (aim_dist_sq >= AIM_R_SQ_IN && aim_dist_sq <= AIM_R_SQ_OUT);

    wire [13:0] cos_approx = (7'd90 - player_angle) * 8'd3;
    wire [13:0] sin_approx = player_angle * 8'd3;
    
    wire signed [15:0] dot_dx_raw = ($signed({1'b0, player_power}) * $signed({2'b0, cos_approx}));
    wire signed [15:0] dot_dy_raw = ($signed({1'b0, player_power}) * $signed({2'b0, sin_approx}));
    wire signed [7:0] aim_dot_dx = dot_dx_raw >>> 7;
    wire signed [7:0] aim_dot_dy = -(dot_dy_raw >>> 7);
    
    wire [6:0] aim_dot_x = (px + aim_dot_dx[6:0]);
    wire [5:0] aim_dot_y = (py + aim_dot_dy[5:0]);
    
    wire aim_dot_hit = (game_phase == PH_AIM) &&
        (pix_x >= aim_dot_x - 7'd1) && (pix_x <= aim_dot_x + 7'd1) &&
        (pix_y >= aim_dot_y - 6'd1) && (pix_y <= aim_dot_y + 6'd1) &&
        (aim_dot_x >= 7'd1) && (aim_dot_y >= 6'd1);

    // ============================================================
    // HP BARS
    // ============================================================
    wire signed [7:0] php_bar_top = $signed({2'b0, py}) - $signed({5'b0, phh}) - 8'sd7;
    wire signed [7:0] php_bar_bot = $signed({2'b0, py}) - $signed({5'b0, phh}) - 8'sd3;
    wire player_hp_bar_region = 
        (pix_x == px || pix_x == px - 7'd1) &&
        ($signed({2'b0, pix_y}) >= php_bar_top) &&
        ($signed({2'b0, pix_y}) <= php_bar_bot) &&
        (php_bar_top >= 0);
    wire [2:0] php_fill = (php >= 6'd50) ? 3'd5 :
                           (php >= 6'd40) ? 3'd4 :
                           (php >= 6'd30) ? 3'd3 :
                           (php >= 6'd20) ? 3'd2 :
                           (php >= 6'd10) ? 3'd1 : 3'd0;
    wire signed [7:0] php_fill_top = php_bar_bot - $signed({5'b0, php_fill}) + 8'sd1;
    wire player_hp_filled = player_hp_bar_region && ($signed({2'b0, pix_y}) >= php_fill_top);

    wire signed [7:0] e0_bar_top = $signed({2'b0, ey0}) - $signed({5'b0, ehh0}) - 8'sd7;
    wire signed [7:0] e0_bar_bot = $signed({2'b0, ey0}) - $signed({5'b0, ehh0}) - 8'sd3;
    wire e0_hp_bar_region = enemy_alive[0] &&
        (pix_x == ex0 || pix_x == ex0 - 7'd1) &&
        ($signed({2'b0, pix_y}) >= e0_bar_top) &&
        ($signed({2'b0, pix_y}) <= e0_bar_bot) &&
        (e0_bar_top >= 0);
    wire [2:0] e0_fill = (ehp0 >= 6'd50) ? 3'd5 :
                          (ehp0 >= 6'd40) ? 3'd4 :
                          (ehp0 >= 6'd30) ? 3'd3 :
                          (ehp0 >= 6'd20) ? 3'd2 :
                          (ehp0 >= 6'd10) ? 3'd1 : 3'd0;
    wire signed [7:0] e0_fill_top = e0_bar_bot - $signed({5'b0, e0_fill}) + 8'sd1;
    wire e0_hp_filled = e0_hp_bar_region && ($signed({2'b0, pix_y}) >= e0_fill_top);

    wire signed [7:0] e1_bar_top = $signed({2'b0, ey1}) - $signed({5'b0, ehh1}) - 8'sd7;
    wire signed [7:0] e1_bar_bot = $signed({2'b0, ey1}) - $signed({5'b0, ehh1}) - 8'sd3;
    wire e1_hp_bar_region = enemy_alive[1] && !current_round &&
        (pix_x == ex1 || pix_x == ex1 - 7'd1) &&
        ($signed({2'b0, pix_y}) >= e1_bar_top) &&
        ($signed({2'b0, pix_y}) <= e1_bar_bot) &&
        (e1_bar_top >= 0);
    wire [2:0] e1_fill = (ehp1 >= 6'd50) ? 3'd5 :
                          (ehp1 >= 6'd40) ? 3'd4 :
                          (ehp1 >= 6'd30) ? 3'd3 :
                          (ehp1 >= 6'd20) ? 3'd2 :
                          (ehp1 >= 6'd10) ? 3'd1 : 3'd0;
    wire signed [7:0] e1_fill_top = e1_bar_bot - $signed({5'b0, e1_fill}) + 8'sd1;
    wire e1_hp_filled = e1_hp_bar_region && ($signed({2'b0, pix_y}) >= e1_fill_top);

    wire signed [7:0] e2_bar_top = $signed({2'b0, ey2}) - $signed({5'b0, ehh2}) - 8'sd7;
    wire signed [7:0] e2_bar_bot = $signed({2'b0, ey2}) - $signed({5'b0, ehh2}) - 8'sd3;
    wire e2_hp_bar_region = enemy_alive[2] && !current_round &&
        (pix_x == ex2 || pix_x == ex2 - 7'd1) &&
        ($signed({2'b0, pix_y}) >= e2_bar_top) &&
        ($signed({2'b0, pix_y}) <= e2_bar_bot) &&
        (e2_bar_top >= 0);
    wire [2:0] e2_fill = (ehp2 >= 6'd50) ? 3'd5 :
                          (ehp2 >= 6'd40) ? 3'd4 :
                          (ehp2 >= 6'd30) ? 3'd3 :
                          (ehp2 >= 6'd20) ? 3'd2 :
                          (ehp2 >= 6'd10) ? 3'd1 : 3'd0;
    wire signed [7:0] e2_fill_top = e2_bar_bot - $signed({5'b0, e2_fill}) + 8'sd1;
    wire e2_hp_filled = e2_hp_bar_region && ($signed({2'b0, pix_y}) >= e2_fill_top);

    // ============================================================
    // ENTITY SPRITES
    // ============================================================
    wire [6:0] girl_left = (px >= 7'd15) ? (px - 7'd15) : 7'd0;
    wire [5:0] girl_top  = (py >= 6'd15) ? (py - 6'd15) : 6'd0;
    
    // FIXED: Full width subtraction first
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

    wire enemy0_vis = (enemy_entity_0 != 46'd0);
    wire enemy0_hit = enemy0_vis &&
                      (ex0 >= {3'd0, ehw0}) && (ey0 >= {3'd0, ehh0}) &&
                      (pix_x >= ex0 - {3'd0, ehw0}) && (pix_x <= ex0 + {3'd0, ehw0}) &&
                      (pix_y >= ey0 - {3'd0, ehh0}) && (pix_y <= ey0 + {3'd0, ehh0});
    wire [15:0] enemy0_color = !enemy_alive[0] ? C_MINION_DEAD :
                               (et0 == 2'b10) ? C_BOSS : C_MINION;

    wire enemy1_vis = !current_round && (enemy_entity_1 != 46'd0);
    wire enemy1_hit = enemy1_vis &&
                      (ex1 >= {3'd0, ehw1}) && (ey1 >= {3'd0, ehh1}) &&
                      (pix_x >= ex1 - {3'd0, ehw1}) && (pix_x <= ex1 + {3'd0, ehw1}) &&
                      (pix_y >= ey1 - {3'd0, ehh1}) && (pix_y <= ey1 + {3'd0, ehh1});
    wire [15:0] enemy1_color = !enemy_alive[1] ? C_MINION_DEAD : C_MINION;

    wire enemy2_vis = !current_round && (enemy_entity_2 != 46'd0);
    wire enemy2_hit = enemy2_vis &&
                      (ex2 >= {3'd0, ehw2}) && (ey2 >= {3'd0, ehh2}) &&
                      (pix_x >= ex2 - {3'd0, ehw2}) && (pix_x <= ex2 + {3'd0, ehw2}) &&
                      (pix_y >= ey2 - {3'd0, ehh2}) && (pix_y <= ey2 + {3'd0, ehh2});
    wire [15:0] enemy2_color = !enemy_alive[2] ? C_MINION_DEAD : C_MINION;

    wire proj_hit = proj_active &&
                    (pix_x >= proj_x) && (pix_x <= proj_x + 7'd1) &&
                    (pix_y >= proj_y) && (pix_y <= proj_y + 6'd1);

    wire trail_dotted = trail_pixel && ((pix_x[0] ^ pix_y[0]) == 1'b0);

    wire terrain_hit = (pix_y >= terrain_height);

    wire gameover_banner = (game_phase == PH_GAMEOVER) &&
                           (pix_x >= 7'd20) && (pix_x <= 7'd75) &&
                           (pix_y >= 6'd25) && (pix_y <= 6'd38);

//    wire [4:0] sky_b = 5'd20 - {1'b0, pix_y[5:2]};
//    wire [15:0] sky_color = {5'd1, 6'd2, sky_b};

    // ============================================================
    // PRIORITY MUX
    // ============================================================
always @(*) begin
        if (!game_started) begin
            pixel_data = bg_pixel;
        end
        else if (gameover_banner)
            pixel_data = victory ? C_VICTORY : C_DEFEAT;
        else if (aim_dot_hit)
            pixel_data = C_AIM_DOT;
        else if (aim_circle_outline)
            pixel_data = C_AIM_CIRCLE;
        else if (proj_hit)
            pixel_data = C_PROJ;
        else if (player_hp_filled || e0_hp_filled || e1_hp_filled || e2_hp_filled)
            pixel_data = C_HP_FILL;
        else if (player_hp_bar_region || e0_hp_bar_region || e1_hp_bar_region || e2_hp_bar_region)
            pixel_data = C_HP_EMPTY;
        else if (in_girl && girl_vis)
            pixel_data = girl_pixel;
        else if (enemy0_hit)
            pixel_data = enemy0_color;
        else if (enemy1_hit)
            pixel_data = enemy1_color;
        else if (enemy2_hit)
            pixel_data = enemy2_color;
        else if (trail_dotted)
            pixel_data = C_TRAIL;
        else
            pixel_data = bg_pixel;
    end

endmodule
