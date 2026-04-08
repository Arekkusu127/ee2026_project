`timescale 1ns / 1ps

module render(
    input  [6:0]  pix_x,
    input  [5:0]  pix_y,
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
    output reg [15:0] pixel_data
);

    // Extract fields from entities
    // [19:13] PosX, [12:7] PosY, [6:3] half_width, [2:0] half_height
    // [45:44] TYPE, [43:38] HP

    wire [6:0] px  = player_entity[19:13];
    wire [5:0] py  = player_entity[12:7];
    wire [3:0] phw = player_entity[6:3];
    wire [2:0] phh = player_entity[2:0];
    wire [5:0] php = player_entity[43:38]; // scaled HP for display

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
    localparam C_TERRAIN  = 16'h07E0;
    localparam C_PLAYER   = 16'hFFE0;
    localparam C_MINION   = 16'hF800;
    localparam C_BOSS     = 16'hF81F;
    localparam C_PROJ     = 16'hFFFF;
    localparam C_HP_BAR   = 16'h07E0;
    localparam C_HP_BG    = 16'h4208;
    localparam C_ENERGY   = 16'h001F;
    localparam C_HUD_BG   = 16'h0000;
    localparam C_VICTORY  = 16'hFFE0;
    localparam C_DEFEAT   = 16'hF800;

    // Player sprite: using entity half_width and half_height
    wire player_hit = (px >= {3'd0, phw}) && (py >= {3'd0, phh}) &&
                      (pix_x >= px - {3'd0, phw}) && (pix_x <= px + {3'd0, phw}) &&
                      (pix_y >= py - {3'd0, phh}) && (pix_y <= py + {3'd0, phh});

    // Enemy 0 sprite (minion or boss, using its own dimensions)
    wire enemy0_hit = enemy_alive[0] &&
                      (ex0 >= {3'd0, ehw0}) && (ey0 >= {3'd0, ehh0}) &&
                      (pix_x >= ex0 - {3'd0, ehw0}) && (pix_x <= ex0 + {3'd0, ehw0}) &&
                      (pix_y >= ey0 - {3'd0, ehh0}) && (pix_y <= ey0 + {3'd0, ehh0});

    // Enemy 1 sprite (minion only in round 1)
    wire enemy1_hit = enemy_alive[1] && !current_round &&
                      (ex1 >= {3'd0, ehw1}) && (ey1 >= {3'd0, ehh1}) &&
                      (pix_x >= ex1 - {3'd0, ehw1}) && (pix_x <= ex1 + {3'd0, ehw1}) &&
                      (pix_y >= ey1 - {3'd0, ehh1}) && (pix_y <= ey1 + {3'd0, ehh1});

    // Enemy 2 sprite (minion only in round 1)
    wire enemy2_hit = enemy_alive[2] && !current_round &&
                      (ex2 >= {3'd0, ehw2}) && (ey2 >= {3'd0, ehh2}) &&
                      (pix_x >= ex2 - {3'd0, ehw2}) && (pix_x <= ex2 + {3'd0, ehw2}) &&
                      (pix_y >= ey2 - {3'd0, ehh2}) && (pix_y <= ey2 + {3'd0, ehh2});

    // Color selection based on entity type
    wire [15:0] enemy0_color = (et0 == 2'b10) ? C_BOSS : C_MINION;

    // Projectile: 2x2
    wire proj_hit = proj_active &&
                    (pix_x >= proj_x) && (pix_x <= proj_x + 7'd1) &&
                    (pix_y >= proj_y) && (pix_y <= proj_y + 6'd1);

    // Terrain
    wire terrain_hit = (pix_y >= terrain_height);

    // HUD region (top 5 rows)
    wire hud_region = (pix_y < 6'd5);

    // Player HP bar: row 1, cols 1..20 (php is 0..63, scale to 20px)
    wire hp_bar_bg = (pix_y == 6'd1) && (pix_x >= 7'd1) && (pix_x <= 7'd20);
    // php max = ~50 for full HP. Scale: fill = php * 20 / 50 ≈ php * 2 / 5
    wire [6:0] hp_fill_wide = {1'b0, php} + {1'b0, php} + {1'b0, php};  // php*3
    wire [4:0] hp_fill_len = (hp_fill_wide[6:2] > 5'd20) ? 5'd20 : hp_fill_wide[6:2]; // /4 approx, clamp to 20
    wire hp_bar_fill = hp_bar_bg && (pix_x <= {2'd0, hp_fill_len});

    // Energy bar: row 3, cols 1..12
    wire en_bar_bg   = (pix_y == 6'd3) && (pix_x >= 7'd1) && (pix_x <= 7'd12);
    wire en_bar_fill = en_bar_bg && (pix_x <= {3'd0, player_energy});

    // Gameover banner
    wire gameover_banner = (game_phase == 3'd6) &&
                           (pix_x >= 7'd28) && (pix_x <= 7'd68) &&
                           (pix_y >= 6'd25) && (pix_y <= 6'd38);

    // Enemy HP mini-bars (1 pixel high, above sprite)
    wire e0_hpbar = enemy_alive[0] &&
                    (ey0 > {3'd0, ehh0} + 6'd1) &&
                    (pix_y == ey0 - {3'd0, ehh0} - 6'd2) &&
                    (pix_x >= (ex0 >= {3'd0, ehw0} ? ex0 - {3'd0, ehw0} : 7'd0)) &&
                    (pix_x <= ex0 + {3'd0, ehw0});
    wire e1_hpbar = enemy_alive[1] && !current_round &&
                    (ey1 > {3'd0, ehh1} + 6'd1) &&
                    (pix_y == ey1 - {3'd0, ehh1} - 6'd2) &&
                    (pix_x >= (ex1 >= {3'd0, ehw1} ? ex1 - {3'd0, ehw1} : 7'd0)) &&
                    (pix_x <= ex1 + {3'd0, ehw1});
    wire e2_hpbar = enemy_alive[2] && !current_round &&
                    (ey2 > {3'd0, ehh2} + 6'd1) &&
                    (pix_y == ey2 - {3'd0, ehh2} - 6'd2) &&
                    (pix_x >= (ex2 >= {3'd0, ehw2} ? ex2 - {3'd0, ehw2} : 7'd0)) &&
                    (pix_x <= ex2 + {3'd0, ehw2});

    // Sky gradient
    wire [4:0] sky_r = 5'd0;
    wire [5:0] sky_g = {1'b0, pix_y[5:1]};
    wire [4:0] sky_b = 5'd31 - pix_y[5:1];
    wire [15:0] sky_color = {sky_r, sky_g, sky_b};

    // ---- 11-layer Priority Mux ----
    always @(*) begin
        if (gameover_banner)
            pixel_data = victory ? C_VICTORY : C_DEFEAT;
        else if (hud_region) begin
            if (hp_bar_fill)
                pixel_data = C_HP_BAR;
            else if (hp_bar_bg)
                pixel_data = C_HP_BG;
            else if (en_bar_fill)
                pixel_data = C_ENERGY;
            else if (en_bar_bg)
                pixel_data = C_HP_BG;
            else
                pixel_data = C_HUD_BG;
        end
        else if (proj_hit)
            pixel_data = C_PROJ;
        else if (e0_hpbar || e1_hpbar || e2_hpbar)
            pixel_data = C_HP_BAR;
        else if (player_hit)
            pixel_data = C_PLAYER;
        else if (enemy0_hit)
            pixel_data = enemy0_color;
        else if (enemy1_hit || enemy2_hit)
            pixel_data = C_MINION;
        else if (terrain_hit)
            pixel_data = C_TERRAIN;
        else
            pixel_data = sky_color;
    end

endmodule
