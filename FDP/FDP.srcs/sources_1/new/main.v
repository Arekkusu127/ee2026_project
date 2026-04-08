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
    input         clk,
    input         btnC,
    input         BTNU,
    input         BTND,
    input         BTNL,
    input         BTNR,
    input  [15:0] sw,
    output [15:0] led,
    output [6:0]  seg,
    output [3:0]  an,
    output        dp,
    output [7:0]  JC_out
);

    wire rst = sw[15];

    // OLED individual signals
    wire oled_cs, oled_sdin, oled_sclk, oled_dc, oled_res, oled_vccen, oled_pmoden;

    // Map to JC_out bus:
    // JC_out[0] = JC1 = CS
    // JC_out[1] = JC2 = MOSI/SDA
    // JC_out[2] = JC3 = unused
    // JC_out[3] = JC4 = SCLK
    // JC_out[4] = JC7 = D/C
    // JC_out[5] = JC8 = RES
    // JC_out[6] = JC9 = VCCEN
    // JC_out[7] = JC10 = PMODEN
    assign JC_out[0] = oled_cs;
    assign JC_out[1] = oled_sdin;
    assign JC_out[2] = 1'b0;
    assign JC_out[3] = oled_sclk;
    assign JC_out[4] = oled_dc;
    assign JC_out[5] = oled_res;
    assign JC_out[6] = oled_vccen;
    assign JC_out[7] = oled_pmoden;

    // ---- Clock generation ----
    wire clk_25, clk_6p25;
    clk_div clk_div_inst (
        .clk100(clk),
        .rst(rst),
        .clk_25(clk_25),
        .clk_6p25(clk_6p25)
    );

    // ---- Debounced buttons ----
    wire fire_pulse, au_pulse, ad_pulse, al_pulse, ar_pulse;
    debounce db_fire (.clk(clk), .rst(rst), .btn_in(btnC),  .btn_out(fire_pulse));
    debounce db_au   (.clk(clk), .rst(rst), .btn_in(BTNU),  .btn_out(au_pulse));
    debounce db_ad   (.clk(clk), .rst(rst), .btn_in(BTND),  .btn_out(ad_pulse));
    debounce db_al   (.clk(clk), .rst(rst), .btn_in(BTNL),  .btn_out(al_pulse));
    debounce db_ar   (.clk(clk), .rst(rst), .btn_in(BTNR),  .btn_out(ar_pulse));

    // ---- Game state signals ----
    wire [2:0]  game_phase;
    wire [6:0]  player_x;
    wire [5:0]  player_y;
    wire [8:0]  player_hp;
    wire [6:0]  player_angle;
    wire [3:0]  player_power;
    wire [3:0]  player_energy;
    wire        current_round;
    wire [2:0]  enemy_alive;
    wire        proj_active;
    wire [6:0]  proj_x;
    wire [5:0]  proj_y;
    wire        victory, defeat;

    // Entity data buses (46 bits per entity)
    wire [45:0] player_entity;
    wire [45:0] enemy_entity_0;
    wire [45:0] enemy_entity_1;
    wire [45:0] enemy_entity_2;

    // ---- Terrain RAM signals ----
    wire [6:0]  terrain_rd_addr_a;
    wire [5:0]  terrain_rd_data_a;
    wire [6:0]  terrain_rd_addr_b;
    wire [5:0]  terrain_rd_data_b;
    wire        terrain_wr_en;
    wire [6:0]  terrain_wr_addr;
    wire [5:0]  terrain_wr_data;

    terrain_ram terrain_inst (
        .clk(clk),
        .rd_addr_a(terrain_rd_addr_a),
        .rd_data_a(terrain_rd_data_a),
        .rd_addr_b(terrain_rd_addr_b),
        .rd_data_b(terrain_rd_data_b),
        .wr_en(terrain_wr_en),
        .wr_addr(terrain_wr_addr),
        .wr_data(terrain_wr_data)
    );

    // ---- Game state FSM ----
    game_state game_fsm (
        .clk(clk),
        .rst(rst),
        .fire_btn(fire_pulse),
        .angle_up(au_pulse),
        .angle_down(ad_pulse),
        .power_up(ar_pulse),
        .power_down(al_pulse),
        .skill_sel(sw[3:0]),
        // terrain interface
        .terrain_rd_addr_a(terrain_rd_addr_a),
        .terrain_rd_data_a(terrain_rd_data_a),
        .terrain_wr_en(terrain_wr_en),
        .terrain_wr_addr(terrain_wr_addr),
        .terrain_wr_data(terrain_wr_data),
        // outputs
        .game_phase(game_phase),
        .player_x(player_x),
        .player_y(player_y),
        .player_hp(player_hp),
        .player_angle(player_angle),
        .player_power(player_power),
        .player_energy(player_energy),
        .current_round(current_round),
        .player_entity(player_entity),
        .enemy_entity_0(enemy_entity_0),
        .enemy_entity_1(enemy_entity_1),
        .enemy_entity_2(enemy_entity_2),
        .enemy_alive(enemy_alive),
        .proj_active(proj_active),
        .proj_x(proj_x),
        .proj_y(proj_y),
        .victory(victory),
        .defeat(defeat)
    );

    // ---- OLED pixel pipeline ----
    wire        frame_begin, sending_pixels, sample_pixel;
    wire [12:0] pixel_index;
    wire [15:0] pixel_data;

    wire [6:0] pix_x;
    wire [5:0] pix_y;
    assign pix_x = pixel_index % 96;
    assign pix_y = pixel_index / 96;

    // Port B for render reads
    assign terrain_rd_addr_b = pix_x;

    render render_inst (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .game_phase(game_phase),
        .player_entity(player_entity),
        .player_angle(player_angle),
        .player_power(player_power),
        .player_energy(player_energy),
        .current_round(current_round),
        .enemy_entity_0(enemy_entity_0),
        .enemy_entity_1(enemy_entity_1),
        .enemy_entity_2(enemy_entity_2),
        .enemy_alive(enemy_alive),
        .proj_active(proj_active),
        .proj_x(proj_x),
        .proj_y(proj_y),
        .terrain_height(terrain_rd_data_b),
        .victory(victory),
        .defeat(defeat),
        .pixel_data(pixel_data)
    );

    // ---- OLED display driver (UNTOUCHED) ----
    Oled_Display oled_inst (
        .clk(clk_6p25),
        .reset(rst),
        .frame_begin(frame_begin),
        .sending_pixels(sending_pixels),
        .sample_pixel(sample_pixel),
        .pixel_index(pixel_index),
        .pixel_data(pixel_data),
        .cs(oled_cs),
        .sdin(oled_sdin),
        .sclk(oled_sclk),
        .d_cn(oled_dc),
        .resn(oled_res),
        .vccen(oled_vccen),
        .pmoden(oled_pmoden)
    );

    // ---- LED output ----
    assign led[2:0]   = game_phase;
    assign led[3]     = current_round;
    assign led[6:4]   = enemy_alive;
    assign led[7]     = proj_active;
    assign led[8]     = victory;
    assign led[9]     = defeat;
    assign led[15:10] = player_angle[5:0];

    // ---- 7-seg display ----
    ss_display seg_inst (
        .clk(clk),
        .rst(rst),
        .player_hp(player_hp),
        .player_power(player_power),
        .seg(seg),
        .an(an),
        .dp(dp)
    );

endmodule
