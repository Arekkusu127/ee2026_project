`timescale 1ns / 1ps
module slime_ctrl(
    input CLOCK, 
    input frame_begin,
    input game_mode,
    output reg [6:0] slime0_x,  // left edge x position
    output reg [6:0] slime1_x,
    output     [5:0] slime_y
    );

    localparam SLIME_W = 14; // change size and boundary here
    localparam SLIME_H = 9;
    localparam SPRITE_PIXELS = SLIME_W * SLIME_H;  // 126 pixels
    localparam LEFT_BOUND = 51; // left boundary for slimes (must be >= 0 and <= X_MAX - SLIME_W)
    localparam RIGHT_BOUND = 82; // right boundary for slimes (must be >= SLIME_W and <= 127)
    localparam GROUND_Y = 54; // y-coordinate of the ground (must be >= SLIME_H and <= 63)

    assign slime_y = GROUND_Y - SLIME_H; // fixed y-coordinate for both slimes
    reg slime0_dir = 1'b0; // moving left
    reg slime1_dir = 1'b0; // moving right
    
    reg [7:0] cnt0 = 0;
    reg [8:0] cnt1 = 0;


    initial begin
        slime0_x = RIGHT_BOUND;
        slime1_x = 7'd96;
    end
    wire slimes_touch = (slime0_x <= slime1_x + SLIME_W-1) && (slime1_x <= slime0_x + SLIME_W-1);

    always @(posedge CLOCK) begin
        if (game_mode && frame_begin) begin

            // ?? Slime0: moves every 6 frames ???????????????
            if (cnt0 == 8'd200) begin
                cnt0 <= 0;
                // Update direction before moving
                if      (slime0_x <= LEFT_BOUND)  slime0_dir = 1'b1;
                else if (slime0_x >= RIGHT_BOUND) slime0_dir = 1'b0;
                else if (slimes_touch) slime0_dir = ~slime0_dir;

                // Move one pixel
                if (slime0_dir)
                    slime0_x <= (slime0_x >= RIGHT_BOUND) ? RIGHT_BOUND : slime0_x + 1;
                else
                    slime0_x <= (slime0_x <= LEFT_BOUND)  ? LEFT_BOUND  : slime0_x - 1;
            end else begin
                cnt0 <= cnt0 + 1;
            end

            // ?? Slime1: moves every 9 frames ???????????????
            if (cnt1 == 9'd260) begin
                cnt1 <= 0;
                if (slime1_x > RIGHT_BOUND) begin
                    // Still entering from off-screen - just walk left
                    slime1_x <= slime1_x - 1;
                end else begin
                    // Now in patrol zone - normal bounce behaviour
                    if      (slime1_x <= LEFT_BOUND)  slime1_dir = 1'b1;
                    else if (slime1_x >= RIGHT_BOUND) slime1_dir = 1'b0;
                    else if (slimes_touch)            slime1_dir = ~slime1_dir;

                    if (slime1_dir)
                        slime1_x <= (slime1_x >= RIGHT_BOUND) ? RIGHT_BOUND : slime1_x + 1;
                    else
                        slime1_x <= (slime1_x <= LEFT_BOUND)  ? LEFT_BOUND  : slime1_x - 1;
                end
            end else begin
                cnt1 <= cnt1 + 1;
            end

        end
    end
endmodule

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

    wire game_fire = game_started ? fire_pulse : 1'b0;
    wire game_au   = game_started ? au_pulse   : 1'b0;
    wire game_ad   = game_started ? ad_pulse   : 1'b0;
    wire game_al   = game_started ? al_pulse   : 1'b0;
    wire game_ar   = game_started ? ar_pulse   : 1'b0;
    wire game_rst  = rst | (!game_started);

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

    wire [45:0] player_entity;
    wire [45:0] enemy_entity_0;
    wire [45:0] enemy_entity_1;
    wire [45:0] enemy_entity_2;
    wire [6:0]  slime0_x;
    wire [6:0] slime1_x;
    wire [5:0] slime_y;

    // ---- Terrain RAM signals ----
    wire [6:0]  terrain_rd_addr_a;
    wire [5:0]  terrain_rd_data_a;
    wire [6:0]  terrain_rd_addr_b;
    wire [5:0]  terrain_rd_data_b;
    wire        terrain_wr_en;
    wire [6:0]  terrain_wr_addr;
    wire [5:0]  terrain_wr_data;
    wire  boss_attack_active;
    wire [6:0] boss_attack_x;

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

    // ---- Trail buffer signals ----
    wire        trail_clear;
    wire        trail_wr_en;
    wire [6:0]  trail_wr_x;
    wire [5:0]  trail_wr_y;
    wire        trail_rd_data;

    wire [6:0] pix_x;
    wire [5:0] pix_y;

    trail_buffer trail_inst (
        .clk(clk),
        .reset(game_rst),
        .trail_clear(trail_clear),
        .trail_wr_en(trail_wr_en),
        .trail_wr_x(trail_wr_x),
        .trail_wr_y(trail_wr_y),
        .trail_rd_x(pix_x),
        .trail_rd_y(pix_y),
        .trail_rd_data(trail_rd_data)
    );

    // ---- Precalculated arc buffer signals ----
    wire        arc_rd_data;
    wire        arc_clear;
    wire        arc_wr_en;
    wire [6:0]  arc_wr_x;
    wire [5:0]  arc_wr_y;

    trail_buffer arc_inst (
        .clk(clk),
        .reset(game_rst),
        .trail_clear(arc_clear),
        .trail_wr_en(arc_wr_en),
        .trail_wr_x(arc_wr_x),
        .trail_wr_y(arc_wr_y),
        .trail_rd_x(pix_x),
        .trail_rd_y(pix_y),
        .trail_rd_data(arc_rd_data)
    );

    // ---- Reticle signals ----
    wire [6:0] reticle_x;
    wire [5:0] reticle_y;

    // ---- Skill selection ----
    reg [3:0] skill_sel;
    always @(*) begin
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
    wire        hit_event;
    wire [7:0]  hit_damage;

    game_state game_fsm (
        .clk(clk),
        .rst(game_rst),
        .fire_btn(game_fire),
        .angle_up(game_au),
        .angle_down(game_ad),
        .move_left(game_al),
        .move_right(game_ar),
        .confirm_aim(game_fire),
        .skill_sel(skill_sel),
        .slime0_x(slime0_x),
        .slime1_x(slime1_x),
        .slime_y(slime_y),
        .terrain_rd_addr_a(terrain_rd_addr_a),
        .terrain_rd_data_a(terrain_rd_data_a),
        .terrain_wr_en(terrain_wr_en),
        .terrain_wr_addr(terrain_wr_addr),
        .terrain_wr_data(terrain_wr_data),
        .trail_clear(trail_clear),
        .trail_wr_en(trail_wr_en),
        .trail_wr_x(trail_wr_x),
        .trail_wr_y(trail_wr_y),
        .arc_clear(arc_clear),
        .arc_wr_en(arc_wr_en),
        .arc_wr_x(arc_wr_x),
        .arc_wr_y(arc_wr_y),
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
        .hit_damage(hit_damage),
        .reticle_x(reticle_x),
        .reticle_y(reticle_y),
        .boss_attack_active(boss_attack_active),
        .boss_attack_x(boss_attack_x)
    );

    // ---- OLED pixel pipeline ----
    wire        frame_begin;
    wire        sending_pixels, sample_pixel;
    wire [12:0] pixel_index;
    wire [15:0] pixel_data;
    wire slime_game_mode = game_started && !current_round && (enemy_alive[0] || enemy_alive[1]) && !victory && !defeat;
    slime_ctrl slime_ctrl_inst (
        .CLOCK(clk),
        .frame_begin(frame_begin),
        .game_mode(slime_game_mode),
        .slime0_x(slime0_x),
        .slime1_x(slime1_x),
        .slime_y(slime_y)
    );
    assign pix_x = pixel_index % 96;
    assign pix_y = pixel_index / 96;

    assign terrain_rd_addr_b = pix_x;

    render render_inst (
        .CLOCK(clk),
        .frame_begin(frame_begin),
        .boss_attack_active(boss_attack_active),
        .boss_attack_x(boss_attack_x),
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
        .slime0_x(slime0_x),
        .slime1_x(slime1_x),
        .slime_y(slime_y),
        .proj_active(proj_active),
        .proj_x(proj_x),
        .proj_y(proj_y),
        .terrain_height(terrain_rd_data_b),
        .victory(victory),
        .defeat(defeat),
        .trail_pixel(trail_rd_data),
        .arc_pixel(arc_rd_data),
        .reticle_x(reticle_x),
        .reticle_y(reticle_y),
        .pixel_data(pixel_data)
    );

    // ---- OLED display driver ----
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
    reg [15:0] led_out;
    always @(*) begin
        if (!game_started) begin
            led_out = 16'hFFFF;
        end else if (game_phase == 3'd7) begin
            case (player_fuel)
                4'd10: led_out = 16'h03FF;
                4'd9:  led_out = 16'h01FF;
                4'd8:  led_out = 16'h00FF;
                4'd7:  led_out = 16'h007F;
                4'd6:  led_out = 16'h003F;
                4'd5:  led_out = 16'h001F;
                4'd4:  led_out = 16'h000F;
                4'd3:  led_out = 16'h0007;
                4'd2:  led_out = 16'h0003;
                4'd1:  led_out = 16'h0001;
                default: led_out = 16'h0000;
            endcase
        end else begin
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

    // ---- 7-seg display ----
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
