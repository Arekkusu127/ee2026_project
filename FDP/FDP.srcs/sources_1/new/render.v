`timescale 1ns / 1ps

module render(
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
    localparam C_TERRAIN      = 16'h07E0;  // green
    localparam C_PLAYER       = 16'hFFE0;  // yellow
    localparam C_PLAYER_DEAD  = 16'h8410;  // grey
    localparam C_MINION       = 16'hF800;  // red
    localparam C_MINION_DEAD  = 16'h8410;  // grey
    localparam C_BOSS         = 16'hF81F;  // magenta
    localparam C_BOSS_DEAD    = 16'h8410;  // grey
    localparam C_PROJ         = 16'hFFFF;  // white
    localparam C_HP_FILL      = 16'h07E0;  // green
    localparam C_HP_EMPTY     = 16'h4208;  // dark grey
    localparam C_AIM_CIRCLE   = 16'hFFFF;  // white
    localparam C_AIM_DOT      = 16'hF800;  // red dot for aim direction
    localparam C_VICTORY      = 16'hFFE0;
    localparam C_DEFEAT       = 16'hF800;
    localparam C_MENU_BG      = 16'h0000;
    localparam C_MENU_TEXT     = 16'hFFFF;
    localparam C_MENU_ACCENT   = 16'hFFE0;

    // ============================================================
    // START MENU
    // ============================================================
    // Simple graphical start menu: title area + "Press C" indicator
    // Title block at center, decorative border
    
    wire menu_border = (!game_started) && (
        (pix_x >= 7'd10 && pix_x <= 7'd85 && (pix_y == 6'd10 || pix_y == 6'd50)) ||
        ((pix_x == 7'd10 || pix_x == 7'd85) && pix_y >= 6'd10 && pix_y <= 6'd50)
    );
    
    // "ARTILLERY" text area (simplified as a colored block)
    wire menu_title = (!game_started) && 
        (pix_x >= 7'd20 && pix_x <= 7'd75 && pix_y >= 6'd18 && pix_y <= 6'd26);
    
    // "Press C" indicator - blinking block
    wire menu_press = (!game_started) &&
        (pix_x >= 7'd30 && pix_x <= 7'd65 && pix_y >= 6'd35 && pix_y <= 6'd43);

    // Decorative crosshair on menu
    wire menu_cross = (!game_started) && (
        ((pix_x == 7'd48) && pix_y >= 6'd28 && pix_y <= 6'd32) ||
        (pix_y == 6'd30 && pix_x >= 7'd46 && pix_x <= 7'd50)
    );

    // ============================================================
    // AIMING CIRCLE (during AIM phase only)
    // ============================================================
    // Circle centered on player, radius 10, white outline
    // A dot on the circle shows the aiming direction
    // Distance from center = power (but circle outline is fixed at r=10)
    
    localparam AIM_R = 10;
    localparam AIM_R_SQ = 100;     // 10^2
    localparam AIM_R_SQ_IN = 81;   // 9^2 (inner bound for outline)
    
    wire signed [7:0] aim_dx = $signed({1'b0, pix_x}) - $signed({1'b0, px});
    wire signed [7:0] aim_dy = $signed({1'b0, pix_y}) - $signed({1'b0, py});
    wire [15:0] aim_dist_sq = aim_dx * aim_dx + aim_dy * aim_dy;
    
    // Circle outline: r=9 to r=10
    wire aim_circle_outline = (game_phase == PH_AIM) && 
        (aim_dist_sq >= AIM_R_SQ_IN && aim_dist_sq <= AIM_R_SQ + 10);

    // Aim direction dot: compute position on circle based on angle and power
    // Use power to show a dot at distance = power from center
    // angle is 0-90 degrees from horizontal
    // For the dot, we use a simple approximation:
    // dot_x = player_x + (power * cos(angle)) / 16 (scaled to fit in circle)
    // dot_y = player_y - (power * sin(angle)) / 16
    // Since power is 1-15, max displacement = 15*256/256 = 15 (but we want within r=10)
    // Scale: dot at distance proportional to power, max at r=10
    // dot_dx = power * cos / (16*256) * 10... let's just use power directly scaled
    
    // Simpler: dot position = center + (power * 10 / 15) in the angle direction
    // We approximate using the LUT values (but we don't have access to LUT here)
    // Instead, use a small inline table for 8 directions approximation
    // OR: compute cos/sin from angle quadrant approximation
    
    // For synthesis friendliness, compute aim dot position:
    // We can approximate: for angle a, cos ≈ (90-a)/90, sin ≈ a/90
    // Better: use actual direction computation
    // aim_dot_dx = (power * cos_approx) >> 4  (divide by 16 to scale into circle)
    // aim_dot_dy = -(power * sin_approx) >> 4
    
    // Simple linear interpolation for cos and sin (0-90 degrees):
    // cos(a) ≈ (90 - a) * 256 / 90  ≈ (90 - a) * 3  (roughly)
    // sin(a) ≈ a * 256 / 90 ≈ a * 3
    
    wire [13:0] cos_approx = (7'd90 - player_angle) * 8'd3; // ~0-270, /256 scale
    wire [13:0] sin_approx = player_angle * 8'd3;
    
    // Dot displacement: scale by power, then normalize to circle radius
    // dot_dx = power * cos_approx / 256 (gives 0 to ~15)
    // But we want max radius = 10 when power = 15
    // dot_dx = power * cos_approx * 10 / (15 * 270) ≈ power * cos_approx / 405
    // Simplify: dot_dx = (power * cos_approx) >> 6  (divide by 64, gives ~0-63/64*15 ≈ 0-4 at low, 0-10 at max)
    // Actually let's be more precise: at power=15, cos=0deg: 15*270/64 ≈ 63 -> too big
    // Use >> 8: 15*270/256 ≈ 15.8 -> slightly over but ok
    // Better: divide by (max_power) then multiply by AIM_R
    // dot_dx = (power * cos_approx * AIM_R) / (15 * 270)
    // = power * cos_approx * 10 / 4050
    // ≈ power * cos_approx / 405
    // ≈ (power * cos_approx) >> 9  (divide by 512, close to 405)
    
    wire signed [15:0] dot_dx_raw = ($signed({1'b0, player_power}) * $signed({2'b0, cos_approx}));
    wire signed [15:0] dot_dy_raw = ($signed({1'b0, player_power}) * $signed({2'b0, sin_approx}));
    wire signed [7:0] aim_dot_dx = dot_dx_raw >>> 9;  // /512
    wire signed [7:0] aim_dot_dy = -(dot_dy_raw >>> 9);
    
    wire [6:0] aim_dot_x = (px + aim_dot_dx[6:0]);
    wire [5:0] aim_dot_y = (py + aim_dot_dy[5:0]);
    
    // Aim dot: 3x3 pixel around the computed position
    wire aim_dot_hit = (game_phase == PH_AIM) &&
        (pix_x >= aim_dot_x - 7'd1) && (pix_x <= aim_dot_x + 7'd1) &&
        (pix_y >= aim_dot_y - 6'd1) && (pix_y <= aim_dot_y + 6'd1) &&
        (aim_dot_x >= 7'd1) && (aim_dot_y >= 6'd1);

    // ============================================================
    // HP BARS: 2 pixels wide x 5 pixels tall, above each entity
    // ============================================================
    // HP bar positioned centered above entity, 2px wide, 5px tall
    // Fill from bottom to top based on HP proportion
    // Max HP stored in entity is 6 bits (0-63), so fill_height = hp * 5 / max_hp
    // For simplicity: fill_height = hp * 5 / 50 = hp / 10 (for entities with max hp=50)
    
    // Player HP bar: positioned at (px-1, py - phh - 7) to (px, py - phh - 3)
    // That's 2 wide, 5 tall
    wire signed [7:0] php_bar_top = $signed({2'b0, py}) - $signed({5'b0, phh}) - 8'sd7;
    wire signed [7:0] php_bar_bot = $signed({2'b0, py}) - $signed({5'b0, phh}) - 8'sd3;
    wire player_hp_bar_region = 
        (pix_x == px || pix_x == px - 7'd1) &&
        ($signed({2'b0, pix_y}) >= php_bar_top) &&
        ($signed({2'b0, pix_y}) <= php_bar_bot) &&
        (php_bar_top >= 0);
    // Fill: hp out of 50 -> fill_rows = php / 10 (0-5)
    wire [2:0] php_fill = (php >= 6'd50) ? 3'd5 :
                           (php >= 6'd40) ? 3'd4 :
                           (php >= 6'd30) ? 3'd3 :
                           (php >= 6'd20) ? 3'd2 :
                           (php >= 6'd10) ? 3'd1 : 3'd0;
    // Fill from bottom: filled if (pix_y >= bar_bot - fill + 1)
    wire signed [7:0] php_fill_top = php_bar_bot - $signed({5'b0, php_fill}) + 8'sd1;
    wire player_hp_filled = player_hp_bar_region && ($signed({2'b0, pix_y}) >= php_fill_top);

    // Enemy 0 HP bar
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

    // Enemy 1 HP bar
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

    // Enemy 2 HP bar
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
    // ENTITY SPRITES (placeholder rectangles, ~8px wide, entity-height tall)
    // Entities turn grey when killed (hp=0 / not alive)
    // ============================================================
    
    // Player sprite
    wire player_hit = (px >= {3'd0, phw}) && (py >= {3'd0, phh}) &&
                      (pix_x >= px - {3'd0, phw}) && (pix_x <= px + {3'd0, phw}) &&
                      (pix_y >= py - {3'd0, phh}) && (pix_y <= py + {3'd0, phh});
    wire player_dead = (php == 6'd0);
    wire [15:0] player_color = player_dead ? C_PLAYER_DEAD : C_PLAYER;

    // Enemy 0 sprite (visible even when dead for grey effect)
    wire enemy0_vis = (enemy_entity_0 != 46'd0);
    wire enemy0_hit = enemy0_vis &&
                      (ex0 >= {3'd0, ehw0}) && (ey0 >= {3'd0, ehh0}) &&
                      (pix_x >= ex0 - {3'd0, ehw0}) && (pix_x <= ex0 + {3'd0, ehw0}) &&
                      (pix_y >= ey0 - {3'd0, ehh0}) && (pix_y <= ey0 + {3'd0, ehh0});
    wire [15:0] enemy0_color = !enemy_alive[0] ? C_MINION_DEAD :
                               (et0 == 2'b10) ? C_BOSS : C_MINION;

    // Enemy 1 sprite
    wire enemy1_vis = !current_round && (enemy_entity_1 != 46'd0);
    wire enemy1_hit = enemy1_vis &&
                      (ex1 >= {3'd0, ehw1}) && (ey1 >= {3'd0, ehh1}) &&
                      (pix_x >= ex1 - {3'd0, ehw1}) && (pix_x <= ex1 + {3'd0, ehw1}) &&
                      (pix_y >= ey1 - {3'd0, ehh1}) && (pix_y <= ey1 + {3'd0, ehh1});
    wire [15:0] enemy1_color = !enemy_alive[1] ? C_MINION_DEAD : C_MINION;

    // Enemy 2 sprite
    wire enemy2_vis = !current_round && (enemy_entity_2 != 46'd0);
    wire enemy2_hit = enemy2_vis &&
                      (ex2 >= {3'd0, ehw2}) && (ey2 >= {3'd0, ehh2}) &&
                      (pix_x >= ex2 - {3'd0, ehw2}) && (pix_x <= ex2 + {3'd0, ehw2}) &&
                      (pix_y >= ey2 - {3'd0, ehh2}) && (pix_y <= ey2 + {3'd0, ehh2});
    wire [15:0] enemy2_color = !enemy_alive[2] ? C_MINION_DEAD : C_MINION;

    // Projectile: 2x2
    wire proj_hit = proj_active &&
                    (pix_x >= proj_x) && (pix_x <= proj_x + 7'd1) &&
                    (pix_y >= proj_y) && (pix_y <= proj_y + 6'd1);

    // Terrain
    wire terrain_hit = (pix_y >= terrain_height);

    // Gameover banner
    wire gameover_banner = (game_phase == PH_GAMEOVER) &&
                           (pix_x >= 7'd20) && (pix_x <= 7'd75) &&
                           (pix_y >= 6'd25) && (pix_y <= 6'd38);

    // Sky gradient
    wire [4:0] sky_b = 5'd20 - {1'b0, pix_y[5:2]};
    wire [15:0] sky_color = {5'd1, 6'd2, sky_b};

    // ============================================================
    // PRIORITY MUX
    // ============================================================
    always @(*) begin
        if (!game_started) begin
            // START MENU
            if (menu_cross)
                pixel_data = C_AIM_DOT;
            else if (menu_title)
                pixel_data = C_MENU_ACCENT;
            else if (menu_press)
                pixel_data = C_MENU_TEXT;
            else if (menu_border)
                pixel_data = C_MENU_ACCENT;
            else
                pixel_data = C_MENU_BG;
        end
        else if (gameover_banner)
            pixel_data = victory ? C_VICTORY : C_DEFEAT;
        else if (aim_dot_hit)
            pixel_data = C_AIM_DOT;
        else if (aim_circle_outline)
            pixel_data = C_AIM_CIRCLE;
        else if (proj_hit)
            pixel_data = C_PROJ;
        // HP bars (filled portions)
        else if (player_hp_filled || e0_hp_filled || e1_hp_filled || e2_hp_filled)
            pixel_data = C_HP_FILL;
        // HP bars (empty portions)
        else if (player_hp_bar_region || e0_hp_bar_region || e1_hp_bar_region || e2_hp_bar_region)
            pixel_data = C_HP_EMPTY;
        // Entity sprites
        else if (player_hit)
            pixel_data = player_color;
        else if (enemy0_hit)
            pixel_data = enemy0_color;
        else if (enemy1_hit)
            pixel_data = enemy1_color;
        else if (enemy2_hit)
            pixel_data = enemy2_color;
        else if (terrain_hit)
            pixel_data = C_TERRAIN;
        else
            pixel_data = sky_color;
    end

endmodule
