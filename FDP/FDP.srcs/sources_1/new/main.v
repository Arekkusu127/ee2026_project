`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
//  STUDENT P NAME: Wang Wanru
//  STUDENT Q NAME: Wei Haowen
//  STUDENT R NAME: Qiang Jiayuan
//  STUDENT S NAME: Sun Shaohan
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

    // ---- Start menu state ----
    // 0 = start menu, 1 = in game
    reg game_started;
    reg fire_pulse_prev;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            game_started <= 0;
            fire_pulse_prev <= 0;
        end else begin
            fire_pulse_prev <= fire_pulse;
            if (!game_started && fire_pulse && !fire_pulse_prev)
                game_started <= 1;
        end
    end

    // Gate inputs to game_state: only pass through when game is started
    wire game_fire = game_started ? fire_pulse : 1'b0;
    wire game_au   = game_started ? au_pulse   : 1'b0;
    wire game_ad   = game_started ? ad_pulse   : 1'b0;
    wire game_al   = game_started ? al_pulse   : 1'b0;
    wire game_ar   = game_started ? ar_pulse   : 1'b0;
    wire game_rst  = rst | (!game_started); // hold game in reset until started

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
    wire [3:0]  player_fuel;
    wire [3:0]  move_phase;  // 1 = moving, 0 = not moving

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

    // ---- Determine skill from switches ----
    // Switches select projectile based on energy cost
    // sw[0] = cost 1, sw[1] = cost 2, ... sw[14] = cost 15, sw[13:0] highest active
    // No switch = basic (cost 0)
    // Player can only use projectiles whose cost <= energy (enforced by LED visibility)
    reg [3:0] skill_sel;
    always @(*) begin
        // Priority encode: highest active switch that is <= energy
        if      (sw[14] && player_energy >= 4'd15) skill_sel = 4'd15;
        else if (sw[13] && player_energy >= 4'd14) skill_sel = 4'd14;
        else if (sw[12] && player_energy >= 4'd13) skill_sel = 4'd13;
        else if (sw[11] && player_energy >= 4'd12) skill_sel = 4'd12;
        else if (sw[10] && player_energy >= 4'd11) skill_sel = 4'd11;
        else if (sw[9]  && player_energy >= 4'd10) skill_sel = 4'd10;
        else if (sw[8]  && player_energy >= 4'd9)  skill_sel = 4'd9;
        else if (sw[7]  && player_energy >= 4'd8)  skill_sel = 4'd8;
        else if (sw[6]  && player_energy >= 4'd7)  skill_sel = 4'd7;
        else if (sw[5]  && player_energy >= 4'd6)  skill_sel = 4'd6;
        else if (sw[4]  && player_energy >= 4'd5)  skill_sel = 4'd5;
        else if (sw[3]  && player_energy >= 4'd4)  skill_sel = 4'd4;
        else if (sw[2]  && player_energy >= 4'd3)  skill_sel = 4'd3;
        else if (sw[1]  && player_energy >= 4'd2)  skill_sel = 4'd2;
        else if (sw[0]  && player_energy >= 4'd1)  skill_sel = 4'd1;
        else                                        skill_sel = 4'd0;
    end

    // ---- Game state FSM ----
    game_state game_fsm (
        .clk(clk),
        .rst(game_rst),
        .fire_btn(game_fire),
        .angle_up(game_au),
        .angle_down(game_ad),
        .power_up(game_ar),
        .power_down(game_ad),
        .move_left(game_al),
        .move_right(game_ar),
        .confirm_aim(game_fire),
        .skill_sel(skill_sel),
        .terrain_rd_addr_a(terrain_rd_addr_a),
        .terrain_rd_data_a(terrain_rd_data_a),
        .terrain_wr_en(terrain_wr_en),
        .terrain_wr_addr(terrain_wr_addr),
        .terrain_wr_data(terrain_wr_data),
        .game_phase(game_phase),
        .player_x(player_x),
        .player_y(player_y),
        .player_hp(player_hp),
        .player_angle(player_angle),
        .player_power(player_power),
        .player_energy(player_energy),
        .player_fuel(player_fuel),
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
        .defeat(defeat),
        .hit_event(hit_event),
        .hit_damage(hit_damage)
    );

    // Hit event signals from game_state
    wire        hit_event;
    wire [7:0]  hit_damage;

    // ---- OLED pixel pipeline ----
    wire        frame_begin, sending_pixels, sample_pixel;
    wire [12:0] pixel_index;
    wire [15:0] pixel_data;

    wire [6:0] pix_x;
    wire [5:0] pix_y;
    assign pix_x = pixel_index % 96;
    assign pix_y = pixel_index / 96;

    assign terrain_rd_addr_b = pix_x;

    render render_inst (
        .pix_x(pix_x),
        .pix_y(pix_y),
        .game_started(game_started),
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

    // ---- LED output: Energy bar OR Fuel gauge ----
    // During MOVE phase: LEDs show fuel (0-10 mapped to 16 LEDs)
    // During AIM/other phases: LEDs show energy (0-16)
    // game_phase: PH_MOVE = 3'd7 (new phase)
    reg [15:0] led_out;
    always @(*) begin
        if (!game_started) begin
            // Idle animation on start menu - all LEDs blink
            led_out = 16'hFFFF;
        end else if (game_phase == 3'd7) begin
            // MOVE phase: fuel gauge
            // player_fuel is 0-10, map to 16 LEDs proportionally
            // fuel 10 = all 16, fuel 5 = 8, fuel 0 = 0
            case (player_fuel)
                4'd10: led_out = 16'hFFFF;
                4'd9:  led_out = 16'h7FFF;
                4'd8:  led_out = 16'h3FFF;
                4'd7:  led_out = 16'h1FFF;
                4'd6:  led_out = 16'h0FFF;
                4'd5:  led_out = 16'h07FF;
                4'd4:  led_out = 16'h03FF;
                4'd3:  led_out = 16'h01FF;
                4'd2:  led_out = 16'h00FF;
                4'd1:  led_out = 16'h007F;
                default: led_out = 16'h0000;
            endcase
        end else begin
            // Energy bar: light up LEDs 0 through (energy-1)
            case (player_energy)
                4'd0:  led_out = 16'h0000;
                4'd1:  led_out = 16'h0001;
                4'd2:  led_out = 16'h0003;
                4'd3:  led_out = 16'h0007;
                4'd4:  led_out = 16'h000F;
                4'd5:  led_out = 16'h001F;
                4'd6:  led_out = 16'h003F;
                4'd7:  led_out = 16'h007F;
                4'd8:  led_out = 16'h00FF;
                4'd9:  led_out = 16'h01FF;
                4'd10: led_out = 16'h03FF;
                4'd11: led_out = 16'h07FF;
                4'd12: led_out = 16'h0FFF;
                4'd13: led_out = 16'h1FFF;
                4'd14: led_out = 16'h3FFF;
                4'd15: led_out = 16'hFFFF;
                default: led_out = 16'h0000;
            endcase
        end
    end
    assign led = led_out;

    // ---- 7-seg display: HP default, damage on hit for 5 seconds ----
    ss_display seg_inst (
        .clk(clk),
        .rst(rst),
        .game_started(game_started),
        .player_hp(player_hp),
        .hit_event(hit_event),
        .hit_damage(hit_damage),
        .seg(seg),
        .an(an),
        .dp(dp)
    );

endmodule
