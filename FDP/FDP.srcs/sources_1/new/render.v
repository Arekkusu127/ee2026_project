`timescale 1ns / 1ps

module render(
    input  [6:0]  px_x,
    input  [5:0]  px_y,
    input  [575:0] terrain_flat,
    input  [6:0]  p0_x,
    input  [5:0]  p0_y,
    input  [6:0]  p1_x,
    input  [5:0]  p1_y,
    input  [7:0]  hp0,
    input  [7:0]  hp1,
    input  [6:0]  proj_x,
    input  [5:0]  proj_y,
    input         proj_active,
    input         turn,
    input  [7:0]  angle,
    input  [3:0]  power,
    input  [4:0]  energy,
    input  [2:0]  phase,
    input         game_over,
    input         winner,
    output reg [15:0] colour
);

    // Unpack terrain
    wire [5:0] terrain [0:95];
    genvar i;
    generate
        for (i = 0; i < 96; i = i + 1) begin : unpack_t
            assign terrain[i] = terrain_flat[i*6 +: 6];
        end
    endgenerate

    // Colours (RGB565)
    localparam SKY_BLUE    = 16'h867F;  // light blue sky
    localparam GROUND_GRN  = 16'h07E0;  // green terrain
    localparam DIRT_BRN    = 16'h8A22;  // brown below surface
    localparam P0_COLOUR   = 16'h001F;  // blue player
    localparam P1_COLOUR   = 16'hF800;  // red player
    localparam PROJ_WHITE  = 16'hFFFF;
    localparam HP_GREEN    = 16'h07E0;
    localparam HP_RED      = 16'hF800;
    localparam HP_BG       = 16'h4208;  // dark gray
    localparam BAR_YELLOW  = 16'hFFE0;
    localparam BAR_CYAN    = 16'h07FF;
    localparam ENERGY_GOLD = 16'hFEA0;
    localparam TURN_IND    = 16'hFFFF;
    localparam GAMEOVER_BG = 16'h0000;
    localparam WIN_TEXT    = 16'hFFE0;

    // HP bar width calculation: (hp * 41) >> 6 approximates hp * 96 / 150
    wire [6:0] hp0_bar = (hp0 * 41) >> 6;
    wire [6:0] hp1_bar = (hp1 * 41) >> 6;

    // Terrain height at current x
    wire [5:0] t_height = (px_x < 7'd96) ? terrain[px_x] : 6'd63;

    // Player 0 sprite: 3x5 box
    wire in_p0 = (px_x >= p0_x - 1) && (px_x <= p0_x + 1) &&
                 (px_y >= p0_y - 2) && (px_y <= p0_y + 2);

    // Player 1 sprite: 3x5 box
    wire in_p1 = (px_x >= p1_x - 1) && (px_x <= p1_x + 1) &&
                 (px_y >= p1_y - 2) && (px_y <= p1_y + 2);

    // Projectile: 2x2
    wire in_proj = proj_active &&
                   (px_x >= proj_x) && (px_x <= proj_x + 1) &&
                   (px_y >= proj_y) && (px_y <= proj_y + 1);

    // HUD regions (top 8 rows)
    // Row 0-1: HP bars (player 0 left half, player 1 right half)
    wire in_hp0_region = (px_y <= 6'd1) && (px_x < 7'd48);
    wire in_hp1_region = (px_y <= 6'd1) && (px_x >= 7'd48);
    wire in_hp0_fill   = in_hp0_region && (px_x < hp0_bar[6:0]);
    wire in_hp1_fill   = in_hp1_region && ((px_x - 7'd48) < hp1_bar[6:0]);

    // Row 2-3: angle bar (width = angle * 96 / 90, approximate as (angle * 17) >> 4)
    wire [6:0] angle_bar_w = (angle * 17) >> 4;
    wire in_angle_bar = (px_y >= 6'd2) && (px_y <= 6'd3) && (px_x < angle_bar_w);

    // Row 4-5: power bar (width = power * 10, max 100 -> clamp at 96)
    wire [6:0] power_bar_w = (power > 4'd9) ? 7'd96 : {3'b0, power} * 7'd10;
    wire in_power_bar = (px_y >= 6'd4) && (px_y <= 6'd5) && (px_x < power_bar_w);

    // Row 6-7: energy dots (each dot = 2px wide, 2px tall, up to 16)
    wire [4:0] energy_dot_idx = px_x[6:1]; // which dot (0..47, but only 0..15 matter)
    wire in_energy = (px_y >= 6'd6) && (px_y <= 6'd7) && 
                     (energy_dot_idx < energy) && (px_x < 7'd32);

    // Turn indicator: small arrow above active player
    wire [6:0] active_x = turn ? p1_x : p0_x;
    wire [5:0] active_y = turn ? p1_y : p0_y;
    wire in_turn_ind = (px_x >= active_x - 1) && (px_x <= active_x + 1) &&
                       (px_y == active_y - 6'd4);

    // Game over overlay
    wire in_gameover_box = game_over &&
                           (px_x >= 7'd20) && (px_x <= 7'd75) &&
                           (px_y >= 6'd24) && (px_y <= 6'd40);
    // Simple "P0" or "P1" winner indicator (just coloured block)
    wire in_winner_text = game_over &&
                          (px_x >= 7'd38) && (px_x <= 7'd58) &&
                          (px_y >= 6'd28) && (px_y <= 6'd36);

    // Priority-based pixel mux
    always @(*) begin
        if (in_gameover_box) begin
            if (in_winner_text)
                colour = winner ? P1_COLOUR : P0_COLOUR;
            else
                colour = GAMEOVER_BG;
        end
        else if (in_turn_ind)
            colour = TURN_IND;
        else if (in_hp0_region)
            colour = in_hp0_fill ? HP_GREEN : HP_BG;
        else if (in_hp1_region)
            colour = in_hp1_fill ? HP_GREEN : HP_BG;
        else if (in_angle_bar)
            colour = BAR_YELLOW;
        else if (in_power_bar)
            colour = BAR_CYAN;
        else if (in_energy)
            colour = ENERGY_GOLD;
        else if (in_proj)
            colour = PROJ_WHITE;
        else if (in_p0)
            colour = P0_COLOUR;
        else if (in_p1)
            colour = P1_COLOUR;
        else if (px_y >= t_height) begin
            if (px_y == t_height)
                colour = GROUND_GRN;
            else
                colour = DIRT_BRN;
        end
        else
            colour = SKY_BLUE;
    end

endmodule
