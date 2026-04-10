`timescale 1ns / 1ps

module game_state(
    input         clk,
    input         rst,
    input         fire_btn,
    input         angle_up,
    input         angle_down,
    input         move_left,
    input         move_right,
    input         confirm_aim,
    input  [3:0]  skill_sel,
    input  [6:0]  slime0_x,
    input  [6:0]  slime1_x,
    input  [5:0]  slime_y,
    output reg [6:0]  terrain_rd_addr_a,
    input      [5:0]  terrain_rd_data_a,
    output reg        terrain_wr_en,
    output reg [6:0]  terrain_wr_addr,
    output reg [5:0]  terrain_wr_data,
    output reg        trail_clear,
    output reg        trail_wr_en,
    output reg [6:0]  trail_wr_x,
    output reg [5:0]  trail_wr_y,
    output reg        arc_clear,
    output reg        arc_wr_en,
    output reg [6:0]  arc_wr_x,
    output reg [5:0]  arc_wr_y,
    output reg [2:0]  game_phase,
    output [6:0]      player_x,
    output [5:0]      player_y,
    output reg [8:0]  player_hp,
    output reg [6:0]  player_angle,
    output reg [3:0]  player_power,
    output reg [3:0]  player_energy,
    output reg [3:0]  player_fuel,
    output reg        current_round,
    output reg [45:0] player_entity,
    output reg [45:0] enemy_entity_0,
    output reg [45:0] enemy_entity_1,
    output reg [45:0] enemy_entity_2,
    output reg [2:0]  enemy_alive,
    output reg        proj_active,
    output reg [6:0]  proj_x,
    output reg [5:0]  proj_y,
    output reg        victory,
    output reg        defeat,
    output reg        hit_event,
    output reg [7:0]  hit_damage,
    output reg [6:0]  reticle_x,
    output reg [5:0]  reticle_y,
    output reg boss_attack_active,
    output reg [6:0] boss_attack_x
);

    localparam PH_INIT     = 3'd0;
    localparam PH_AIM      = 3'd1;
    localparam PH_FIRE     = 3'd2;
    localparam PH_ANIMATE  = 3'd3;
    localparam PH_RESOLVE  = 3'd4;
    localparam PH_NEXTTURN = 3'd5;
    localparam PH_GAMEOVER = 3'd6;
    localparam PH_MOVE     = 3'd7;

    localparam TYPE_PLAYER = 2'b00;
    localparam TYPE_MINION = 2'b01;
    localparam TYPE_BOSS   = 2'b10;

    localparam [9:0] AIM_RADIUS_SQ = 10'd400;
    localparam EXPLOSION_RADIUS = 4'd8;  // Max explosion radius in pixels

    function [45:0] pack_entity;
        input [1:0]  etype;
        input [5:0]  hp;
        input [5:0]  def_val;
        input [5:0]  atk;
        input [5:0]  mp;
        input [6:0]  px;
        input [5:0]  py;
        input [3:0]  hw;
        input [2:0]  hh;
        begin
            pack_entity = {etype, hp, def_val, atk, mp, px, py, hw, hh};
        end
    endfunction

    function [1:0] ent_type;   input [45:0] e; ent_type   = e[45:44]; endfunction
    function [5:0] ent_hp;     input [45:0] e; ent_hp     = e[43:38]; endfunction
    function [5:0] ent_def;    input [45:0] e; ent_def    = e[37:32]; endfunction
    function [5:0] ent_atk;    input [45:0] e; ent_atk    = e[31:26]; endfunction
    function [5:0] ent_mp;     input [45:0] e; ent_mp     = e[25:20]; endfunction
    function [6:0] ent_px;     input [45:0] e; ent_px     = e[19:13]; endfunction
    function [5:0] ent_py;     input [45:0] e; ent_py     = e[12:7];  endfunction
    function [3:0] ent_hw;     input [45:0] e; ent_hw     = e[6:3];   endfunction
    function [2:0] ent_hh;     input [45:0] e; ent_hh     = e[2:0];   endfunction

    function [45:0] set_hp;
        input [45:0] e;
        input [5:0]  new_hp;
        begin
            set_hp = {e[45:44], new_hp, e[37:0]};
        end
    endfunction

    function [45:0] set_pos;
        input [45:0] e;
        input [6:0]  new_x;
        input [5:0]  new_y;
        begin
            set_pos = {e[45:20], new_x, new_y, e[6:0]};
        end
    endfunction

    assign player_x = ent_px(player_entity);
    assign player_y = ent_py(player_entity);

    reg [8:0] real_hp_player;
    reg [8:0] real_hp_enemy [0:2];
    reg [8:0] next_player_hp;
    reg [8:0] next_enemy_hp0;
    reg [8:0] next_enemy_hp1;
    reg [8:0] next_enemy_hp2;
    reg [2:0] next_enemy_alive;
    reg [5:0] enemy_attack_damage;
    reg boss_beam_hit_player;
    reg player_hit_boss;

    // ---- Projectile physics ----
    reg signed [20:0] proj_fx, proj_fy;
    reg signed [15:0] proj_vx, proj_vy;

    localparam signed [15:0] GRAVITY = 16'sd600;

    reg [2:0] trail_tick_cnt;

    reg [21:0] tick_cnt;
    wire tick_30hz = (tick_cnt == 22'd3_333_333);
    always @(posedge clk or posedge rst) begin
        if (rst)
            tick_cnt <= 0;
        else if (tick_30hz)
            tick_cnt <= 0;
        else
            tick_cnt <= tick_cnt + 1;
    end

    wire [15:0] rng;
    lfsr16 lfsr_inst (.clk(clk), .rst(rst), .rng(rng));

    reg  [6:0] lut_angle;
    wire [8:0] sin_val, cos_val;
    sin_lut sin_inst (.angle(lut_angle), .sin_val(sin_val));
    cos_lut cos_inst (.angle(lut_angle), .cos_val(cos_val));

    reg        is_player_turn;
    reg [1:0]  current_enemy_idx;

    reg [5:0]  skill_damage;
    reg [3:0]  skill_blast;
    reg [3:0]  skill_energy_cost;
    reg [1:0]  skill_type;  // 0=basic, 1=spread, 2=explosive_radius, 3=explosive_damage

    reg [9:0]  anim_ticks;
    reg [5:0]  ai_delay;
    reg [6:0]  init_col;
    reg [2:0]  init_step;
    reg [2:0]  resolve_step;
    reg signed [7:0] blast_dx;
    reg        fire_dir_right;
    reg [6:0]  ai_angle;
    reg [3:0]  ai_power;
    reg        lut_ready;
    reg [1:0]  move_step;
    reg [6:0]  move_target_x;
    reg [1:0]  fire_step;

    // ---- Multi-projectile support (for spread shot) ----
    reg [1:0]  spread_idx;       // which spread projectile (0,1,2)
    reg [1:0]  spread_count;     // total projectiles to fire (1 or 3)
    reg        spread_pending;   // more projectiles to fire after current one resolves
    // Accumulated damage across spread projectiles
    reg [8:0]  spread_dmg_enemy0;
    reg [8:0]  spread_dmg_enemy1;
    reg [8:0]  spread_dmg_boss;

    // ---- Explosive radius for skill types 2,3 ----
    reg [3:0]  effective_blast;
    reg [3:0] explosion_radius;
    reg [6:0] explosion_center_x;
    reg [5:0] explosion_center_y;
    reg       explosion_pending;

    // ---- Precalculated arc state ----
    reg [1:0]  arc_calc_state;
    reg [6:0]  arc_step;
    reg signed [20:0] arc_fx, arc_fy;
    reg signed [15:0] arc_vx, arc_vy;
    reg        arc_needs_update;
    reg [6:0]  last_reticle_x;
    reg [5:0]  last_reticle_y;

    // ---- Reticle circle constraint ----
    wire [6:0] cand_x_up    = reticle_x;
    wire [5:0] cand_y_up    = (reticle_y > 6'd0)  ? reticle_y - 6'd1 : 6'd0;
    wire [6:0] cand_x_down  = reticle_x;
    wire [5:0] cand_y_down  = (reticle_y < 6'd63) ? reticle_y + 6'd1 : 6'd63;
    wire [6:0] cand_x_left  = (reticle_x > 7'd0)  ? reticle_x - 7'd1 : 7'd0;
    wire [5:0] cand_y_left  = reticle_y;
    wire [6:0] cand_x_right = (reticle_x < 7'd95) ? reticle_x + 7'd1 : 7'd95;
    wire [5:0] cand_y_right = reticle_y;

    wire [6:0] pcx = ent_px(player_entity);
    wire [5:0] pcy = ent_py(player_entity);

    wire signed [7:0] dx_up    = $signed({1'b0, cand_x_up})    - $signed({1'b0, pcx});
    wire signed [7:0] dy_up    = $signed({2'b0, cand_y_up})    - $signed({2'b0, pcy});
    wire signed [7:0] dx_down  = $signed({1'b0, cand_x_down})  - $signed({1'b0, pcx});
    wire signed [7:0] dy_down  = $signed({2'b0, cand_y_down})  - $signed({2'b0, pcy});
    wire signed [7:0] dx_left  = $signed({1'b0, cand_x_left})  - $signed({1'b0, pcx});
    wire signed [7:0] dy_left  = $signed({2'b0, cand_y_left})  - $signed({2'b0, pcy});
    wire signed [7:0] dx_right = $signed({1'b0, cand_x_right}) - $signed({1'b0, pcx});
    wire signed [7:0] dy_right = $signed({2'b0, cand_y_right}) - $signed({2'b0, pcy});

    wire [15:0] dsq_up    = dx_up    * dx_up    + dy_up    * dy_up;
    wire [15:0] dsq_down  = dx_down  * dx_down  + dy_down  * dy_down;
    wire [15:0] dsq_left  = dx_left  * dx_left  + dy_left  * dy_left;
    wire [15:0] dsq_right = dx_right * dx_right + dy_right * dy_right;

    wire allow_up    = (dsq_up    <= {6'd0, AIM_RADIUS_SQ});
    wire allow_down  = (dsq_down  <= {6'd0, AIM_RADIUS_SQ});
    wire allow_left  = (dsq_left  <= {6'd0, AIM_RADIUS_SQ});
    wire allow_right = (dsq_right <= {6'd0, AIM_RADIUS_SQ});

    wire signed [7:0] ret_dx = $signed({1'b0, reticle_x}) - $signed({1'b0, pcx});
    wire signed [7:0] ret_dy = $signed({2'b0, reticle_y}) - $signed({2'b0, pcy});

    wire [6:0] abs_dx = ret_dx[7] ? (~ret_dx[6:0] + 7'd1) : ret_dx[6:0];
    wire [5:0] abs_dy = ret_dy[7] ? (~ret_dy[5:0] + 6'd1) : ret_dy[5:0];

    wire [15:0] ret_dsq = ret_dx * ret_dx + ret_dy * ret_dy;

    wire [3:0] computed_power = (ret_dsq >= 16'd348) ? 4'd15 :
                                (ret_dsq >= 16'd300) ? 4'd14 :
                                (ret_dsq >= 16'd256) ? 4'd13 :
                                (ret_dsq >= 16'd215) ? 4'd12 :
                                (ret_dsq >= 16'd178) ? 4'd11 :
                                (ret_dsq >= 16'd144) ? 4'd10 :
                                (ret_dsq >= 16'd114) ? 4'd9  :
                                (ret_dsq >= 16'd87)  ? 4'd8  :
                                (ret_dsq >= 16'd64)  ? 4'd7  :
                                (ret_dsq >= 16'd44)  ? 4'd6  :
                                (ret_dsq >= 16'd28)  ? 4'd5  :
                                (ret_dsq >= 16'd16)  ? 4'd4  :
                                (ret_dsq >= 16'd7)   ? 4'd3  :
                                (ret_dsq >= 16'd2)   ? 4'd2  : 4'd1;

    wire [12:0] dy_64     = {7'b0, abs_dy} << 6;
    wire [12:0] dx_tan10  = {6'b0, abs_dx} * 7'd11;
    wire [12:0] dx_tan20  = {6'b0, abs_dx} * 7'd23;
    wire [12:0] dx_tan30  = {6'b0, abs_dx} * 7'd37;
    wire [12:0] dx_tan40  = {6'b0, abs_dx} * 7'd54;
    wire [12:0] dx_tan50  = {6'b0, abs_dx} * 7'd76;
    wire [12:0] dx_tan60  = {6'b0, abs_dx} * 13'd111;
    wire [12:0] dx_tan70  = {6'b0, abs_dx} * 13'd176;
    wire [12:0] dx_tan80  = {6'b0, abs_dx} * 13'd362;

    wire [6:0] computed_angle_raw = (abs_dx == 0 && abs_dy == 0) ? 7'd45 :
                                    (abs_dx == 0)                 ? 7'd90 :
                                    (abs_dy == 0)                 ? 7'd0  :
                                    (dy_64 >= dx_tan80)           ? 7'd85 :
                                    (dy_64 >= dx_tan70)           ? 7'd75 :
                                    (dy_64 >= dx_tan60)           ? 7'd65 :
                                    (dy_64 >= dx_tan50)           ? 7'd55 :
                                    (dy_64 >= dx_tan40)           ? 7'd45 :
                                    (dy_64 >= dx_tan30)           ? 7'd35 :
                                    (dy_64 >= dx_tan20)           ? 7'd25 :
                                    (dy_64 >= dx_tan10)           ? 7'd15 :
                                                                    7'd5;

    wire reticle_above = ret_dy[7];
    wire reticle_right = !ret_dx[7];
    wire [6:0] launch_elevation = reticle_above ? computed_angle_raw : 7'd0;
function [5:0] scale_boss_hp_400_to_63;
    input [8:0] hp9;
    reg [14:0] scaled_num;
    reg [5:0]  scaled_hp;
    begin
        if (hp9 >= 9'd400) begin
            scale_boss_hp_400_to_63 = 6'd63;
        end else if (hp9 == 9'd0) begin
            scale_boss_hp_400_to_63 = 6'd0;
        end else begin
            scaled_num = hp9 * 7'd63;
            scaled_hp  = scaled_num / 9'd400;
            scale_boss_hp_400_to_63 = (scaled_hp == 6'd0) ? 6'd1 : scaled_hp;
        end
    end
endfunction

    // ---- Skill decoder with skill types ----
    // Type 0: basic (energy 0-4), single projectile
    // Type 1: spread (energy 5-8), three projectiles
    // Type 2: explosive radius (energy 9-12), single with big blast
    // Type 3: explosive damage (energy 13-15), single with big damage
    always @(*) begin
        case (skill_sel)
            // Basic projectiles (0-4): increasing damage, small blast
            4'd0:  begin skill_damage = 6'd10; skill_blast = 4'd2; skill_energy_cost = 4'd0;  skill_type = 2'd0; end
            4'd1:  begin skill_damage = 6'd13; skill_blast = 4'd2; skill_energy_cost = 4'd1;  skill_type = 2'd0; end
            4'd2:  begin skill_damage = 6'd16; skill_blast = 4'd2; skill_energy_cost = 4'd2;  skill_type = 2'd0; end
            4'd3:  begin skill_damage = 6'd19; skill_blast = 4'd3; skill_energy_cost = 4'd3;  skill_type = 2'd0; end
            4'd4:  begin skill_damage = 6'd22; skill_blast = 4'd3; skill_energy_cost = 4'd4;  skill_type = 2'd0; end
            // Spread projectiles (5-8): three shots, increasing damage
            4'd5:  begin skill_damage = 6'd12; skill_blast = 4'd2; skill_energy_cost = 4'd5;  skill_type = 2'd1; end
            4'd6:  begin skill_damage = 6'd15; skill_blast = 4'd2; skill_energy_cost = 4'd6;  skill_type = 2'd1; end
            4'd7:  begin skill_damage = 6'd18; skill_blast = 4'd3; skill_energy_cost = 4'd7;  skill_type = 2'd1; end
            4'd8:  begin skill_damage = 6'd21; skill_blast = 4'd3; skill_energy_cost = 4'd8;  skill_type = 2'd1; end
            // Explosive radius (9-12): single shot, increasing blast radius
            4'd9:  begin skill_damage = 6'd20; skill_blast = 4'd5; skill_energy_cost = 4'd9;  skill_type = 2'd2; end
            4'd10: begin skill_damage = 6'd22; skill_blast = 4'd6; skill_energy_cost = 4'd10; skill_type = 2'd2; end
            4'd11: begin skill_damage = 6'd24; skill_blast = 4'd7; skill_energy_cost = 4'd11; skill_type = 2'd2; end
            4'd12: begin skill_damage = 6'd26; skill_blast = 4'd8; skill_energy_cost = 4'd12; skill_type = 2'd2; end
            // Explosive damage (13-15): single shot, big damage
            4'd13: begin skill_damage = 6'd40; skill_blast = 4'd4; skill_energy_cost = 4'd13; skill_type = 2'd3; end
            4'd14: begin skill_damage = 6'd50; skill_blast = 4'd4; skill_energy_cost = 4'd14; skill_type = 2'd3; end
            4'd15: begin skill_damage = 6'd63; skill_blast = 4'd5; skill_energy_cost = 4'd15; skill_type = 2'd3; end
            default: begin skill_damage = 6'd10; skill_blast = 4'd2; skill_energy_cost = 4'd0; skill_type = 2'd0; end
        endcase
    end

    function [7:0] manhattan;
        input [6:0] x1;
        input [5:0] y1;
        input [6:0] x2;
        input [5:0] y2;
        reg [6:0] adx;
        reg [5:0] ady;
        begin
            adx = (x1 > x2) ? (x1 - x2) : (x2 - x1);
            ady = (y1 > y2) ? (y1 - y2) : (y2 - y1);
            manhattan = {1'b0, adx} + {2'b00, ady};
        end
    endfunction

    reg [5:0] computed_terrain;
    always @(*) begin
        computed_terrain = 6'd50;
    end

    always @(*) begin
        player_hp = real_hp_player;
    end

    // ---- Boss sprite collision constants (matching render module) ----
    localparam [6:0] BOSS_SPRITE_LEFT  = 7'd55;
    localparam [5:0] BOSS_SPRITE_TOP   = 6'd7;
    localparam [6:0] BOSS_SPRITE_W     = 7'd40;
    localparam [5:0] BOSS_SPRITE_H     = 6'd50;

    // ---- Spread angle offsets (in degrees from base angle) ----
    // Spread fires at base angle, base+10, base-10
    reg signed [7:0] spread_angle_offset;
    always @(*) begin
        case (spread_idx)
            2'd0: spread_angle_offset = 8'sd0;    // center
            2'd1: spread_angle_offset = 8'sd10;   // up
            2'd2: spread_angle_offset = -8'sd10;  // down
            default: spread_angle_offset = 8'sd0;
        endcase
    end

    // ====== MAIN FSM ======
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            player_hit_boss  = 0;
            boss_beam_hit_player <= 0;
            boss_attack_active <= 0;
            boss_attack_x     <= 0;
            game_phase        <= PH_INIT;
            real_hp_player    <= 9'd200;
            player_angle      <= 7'd45;
            player_power      <= 4'd8;
            player_energy     <= 4'd4;   // Start with 4 energy
            player_fuel       <= 4'd10;
            current_round     <= 0;
            enemy_alive       <= 3'b011;
            proj_active       <= 0;
            proj_x            <= 0;
            proj_y            <= 0;
            proj_fx           <= 0;
            proj_fy           <= 0;
            proj_vx           <= 0;
            proj_vy           <= 0;
            victory           <= 0;
            defeat            <= 0;
            is_player_turn    <= 1;
            current_enemy_idx <= 0;
            terrain_wr_en     <= 0;
            init_col          <= 0;
            init_step         <= 0;
            anim_ticks        <= 0;
            ai_delay          <= 0;
            resolve_step      <= 0;
            blast_dx          <= 0;
            fire_dir_right    <= 1;
            lut_angle         <= 0;
            lut_ready         <= 0;
            ai_angle          <= 7'd45;
            ai_power          <= 4'd7;
            hit_event         <= 0;
            hit_damage        <= 0;
            move_step         <= 0;
            move_target_x     <= 0;
            trail_clear       <= 0;
            trail_wr_en       <= 0;
            trail_wr_x        <= 0;
            trail_wr_y        <= 0;
            trail_tick_cnt    <= 0;
            fire_step         <= 0;
            reticle_x         <= 7'd30;
            reticle_y         <= 6'd20;
            arc_clear         <= 0;
            arc_wr_en         <= 0;
            arc_wr_x          <= 0;
            arc_wr_y          <= 0;
            arc_calc_state    <= 2'd0;
            arc_step          <= 0;
            arc_fx            <= 0;
            arc_fy            <= 0;
            arc_vx            <= 0;
            arc_vy            <= 0;
            arc_needs_update  <= 0;
            last_reticle_x    <= 7'd0;
            last_reticle_y    <= 6'd0;
            spread_idx        <= 0;
            spread_count      <= 1;
            spread_pending    <= 0;
            spread_dmg_enemy0 <= 0;
            spread_dmg_enemy1 <= 0;
            spread_dmg_boss   <= 0;
            effective_blast   <= 0;
            player_entity     <= pack_entity(TYPE_PLAYER, 6'd50, 6'd5, 6'd25, 6'd12, 7'd20, 6'd0, 4'd3, 3'd3);
            enemy_entity_0 <= pack_entity(TYPE_MINION, 6'd50, 6'd0, 6'd0, 6'd0, 7'd89, 6'd49, 4'd7, 3'd4);
            enemy_entity_1 <= pack_entity(TYPE_MINION, 6'd50, 6'd0, 6'd0, 6'd0, 7'd103, 6'd49, 4'd7, 3'd4);
            enemy_entity_2 <= 46'd0;
            real_hp_enemy[0] <= 9'd50;
            real_hp_enemy[1] <= 9'd50;
            real_hp_enemy[2] <= 9'd0;
        end else begin
            terrain_wr_en <= 0;
            trail_clear   <= 0;
            trail_wr_en   <= 0;
            arc_clear     <= 0;
            arc_wr_en     <= 0;

            if (hit_event && tick_30hz)
                hit_event <= 0;

            // ---- Precalculated arc computation ----
            if (game_phase == PH_AIM && is_player_turn) begin
                if (reticle_x != last_reticle_x || reticle_y != last_reticle_y) begin
                    arc_needs_update <= 1;
                    last_reticle_x   <= reticle_x;
                    last_reticle_y   <= reticle_y;
                end

                case (arc_calc_state)
                2'd0: begin
                    if (arc_needs_update) begin
                        arc_clear      <= 1;
                        arc_calc_state <= 2'd1;
                        arc_step       <= 0;
                        arc_needs_update <= 0;
                        arc_fx <= {ent_px(player_entity), 8'd128};
                        arc_fy <= {ent_py(player_entity), 8'd0};
                        if (reticle_right)
                            arc_vx <= $signed({1'b0, computed_power}) * $signed({1'b0, cos_val});
                        else
                            arc_vx <= -($signed({1'b0, computed_power}) * $signed({1'b0, cos_val}));
                        if (reticle_above)
                            arc_vy <= -($signed({1'b0, computed_power}) * $signed({1'b0, sin_val}));
                        else
                            arc_vy <= $signed({1'b0, computed_power}) * $signed({1'b0, sin_val});
                    end
                end
                2'd1: begin
                    if (arc_step < 7'd120) begin
                        arc_fx <= arc_fx + {{5{arc_vx[15]}}, arc_vx};
                        arc_fy <= arc_fy + {{5{arc_vy[15]}}, arc_vy};
                        arc_vy <= arc_vy + GRAVITY;
                        arc_step <= arc_step + 1;
                        if (!arc_fx[20] && arc_fx[14:8] < 7'd96 &&
                            !arc_fy[20] && arc_fy[13:8] < 7'd64) begin
                            if (arc_step[1:0] == 2'b00) begin
                                arc_wr_en <= 1;
                                arc_wr_x  <= arc_fx[14:8];
                                arc_wr_y  <= arc_fy[13:8];
                            end
                        end
                        if (arc_fx[20] || arc_fx[14:8] >= 7'd96 ||
                            arc_fy[20] || arc_fy[13:8] >= 6'd63) begin
                            arc_calc_state <= 2'd2;
                        end
                    end else begin
                        arc_calc_state <= 2'd2;
                    end
                end
                2'd2: begin
                    if (arc_needs_update)
                        arc_calc_state <= 2'd0;
                end
                default: arc_calc_state <= 2'd0;
                endcase
            end else begin
                if (game_phase != PH_AIM) begin
                    arc_calc_state <= 2'd0;
                    arc_needs_update <= 0;
                end
            end

            case (game_phase)

            // ===== INIT =====
            PH_INIT: begin
                case (init_step)
                3'd0: begin
                    terrain_wr_en   <= 1;
                    terrain_wr_addr <= init_col;
                    terrain_wr_data <= computed_terrain;
                    init_step       <= 3'd1;
                end
                3'd1: begin
                    if (init_col == 7'd95) begin
                        init_col  <= 0;
                        init_step <= 3'd2;
                    end else begin
                        init_col  <= init_col + 1;
                        init_step <= 3'd0;
                    end
                end
                3'd2: begin
                    terrain_rd_addr_a <= ent_px(player_entity);
                    init_step <= 3'd3;
                end
                3'd3: begin
                    player_entity <= set_pos(player_entity,
                        ent_px(player_entity),
                        (terrain_rd_data_a >= 6'd6) ? terrain_rd_data_a - 6'd5 : 6'd1);
                    terrain_rd_addr_a <= ent_px(enemy_entity_0);
                    init_step <= 3'd4;
                end
                3'd4: begin
                    enemy_entity_0 <= set_pos(enemy_entity_0,
                        ent_px(enemy_entity_0),
                        (terrain_rd_data_a >= 6'd7) ? terrain_rd_data_a - 6'd6 : 6'd1);
                    terrain_rd_addr_a <= ent_px(enemy_entity_1);
                    init_step <= 3'd5;
                end
                3'd5: begin
                    enemy_entity_1 <= set_pos(enemy_entity_1,
                        ent_px(enemy_entity_1),
                        (terrain_rd_data_a >= 6'd7) ? terrain_rd_data_a - 6'd6 : 6'd1);
                    terrain_rd_addr_a <= ent_px(enemy_entity_2);
                    init_step <= 3'd6;
                end
                3'd6: begin
                    enemy_entity_2 <= set_pos(enemy_entity_2,
                        ent_px(enemy_entity_2),
                        (terrain_rd_data_a >= 6'd7) ? terrain_rd_data_a - 6'd6 : 6'd1);
                    init_step <= 3'd7;
                end
                3'd7: begin
                    game_phase        <= PH_MOVE;
                    is_player_turn    <= 1'b1;
                    current_enemy_idx <= 2'd0;
                    player_fuel       <= 4'd10;
                    init_step         <= 0;
                    init_col          <= 0;
                    move_step         <= 0;
                end
                default: init_step <= 3'd0;
                endcase
            end

            // ===== MOVE =====
            PH_MOVE: begin
                if (is_player_turn) begin
                    case (move_step)
                    2'd0: begin
                        if (confirm_aim || player_fuel == 4'd0) begin
                            game_phase <= PH_AIM;
                            move_step  <= 0;
                            if (ent_px(player_entity) + 7'd14 <= 7'd95)
                                reticle_x <= ent_px(player_entity) + 7'd14;
                            else
                                reticle_x <= 7'd95;
                            if (ent_py(player_entity) >= 6'd14)
                                reticle_y <= ent_py(player_entity) - 6'd14;
                            else
                                reticle_y <= 6'd0;
                            arc_needs_update <= 1;
                            last_reticle_x   <= 7'h7F;
                            last_reticle_y   <= 6'h3F;
                            arc_calc_state   <= 2'd0;
                            lut_angle <= launch_elevation;
                        end else if (move_left && player_fuel > 0) begin
                            if (ent_px(player_entity) > 7'd1) begin
                                move_target_x <= ent_px(player_entity) - 7'd1;
                                terrain_rd_addr_a <= ent_px(player_entity) - 7'd1;
                                move_step <= 2'd1;
                            end
                        end else if (move_right && player_fuel > 0) begin
                            if (ent_px(player_entity) < 7'd94) begin
                                move_target_x <= ent_px(player_entity) + 7'd1;
                                terrain_rd_addr_a <= ent_px(player_entity) + 7'd1;
                                move_step <= 2'd1;
                            end
                        end
                    end
                    2'd1: begin
                        move_step <= 2'd2;
                    end
                    2'd2: begin
                        player_entity <= set_pos(player_entity,
                            move_target_x,
                            (terrain_rd_data_a >= 6'd6) ? terrain_rd_data_a - 6'd5 : 6'd1);
                        player_fuel <= player_fuel - 1;
                        move_step <= 2'd0;
                    end
                    default: move_step <= 2'd0;
                    endcase
                end else begin
                    game_phase <= PH_AIM;
                end
            end

            // ===== AIM =====
            PH_AIM: begin
                if (is_player_turn) begin
                    if (angle_up && allow_up)
                        reticle_y <= cand_y_up;
                    if (angle_down && allow_down)
                        reticle_y <= cand_y_down;
                    if (move_left && allow_left)
                        reticle_x <= cand_x_left;
                    if (move_right && allow_right)
                        reticle_x <= cand_x_right;

                    lut_angle <= launch_elevation;
                    player_angle <= launch_elevation;
                    player_power <= computed_power;

                    if (fire_btn) begin
                        if (player_energy >= skill_energy_cost) begin
                            player_energy  <= player_energy - skill_energy_cost;
                            fire_dir_right <= reticle_right;
                            lut_angle      <= launch_elevation;
                            game_phase     <= PH_FIRE;
                            lut_ready      <= 0;
                            fire_step      <= 0;
                            trail_clear    <= 1;
                            arc_clear      <= 1;
                            // Set up spread count
                            if (skill_type == 2'd1) begin
                                spread_count <= 2'd3;
                            end else begin
                                spread_count <= 2'd1;
                            end
                            spread_idx        <= 0;
                            spread_pending    <= 0;
                            spread_dmg_enemy0 <= 0;
                            spread_dmg_enemy1 <= 0;
                            spread_dmg_boss   <= 0;
                            // Set effective blast radius
                            effective_blast <= skill_blast;
                        end
                    end
                end else begin
                    if (current_round) begin
                        if (ai_delay < 6'd20) begin
                            if (tick_30hz) ai_delay <= ai_delay + 1;
                        end else begin
                            ai_delay   <= 0;
                            game_phase <= PH_FIRE;
                            fire_step  <= 0;
                            spread_count <= 2'd1;
                            spread_idx   <= 0;
                            spread_pending <= 0;
                            spread_dmg_enemy0 <= 0;
                            spread_dmg_enemy1 <= 0;
                            spread_dmg_boss   <= 0;
                        end
                    end else begin
                        if (ai_delay < 6'd30) begin
                            if (tick_30hz) ai_delay <= ai_delay + 1;
                        end else begin
                            ai_delay       <= 0;
                            fire_dir_right <= 0;
                            ai_angle       <= 7'd40 + {3'd0, rng[3:0]};
                            ai_power       <= 4'd6  + {2'd0, rng[5:4]};
                            game_phase     <= PH_FIRE;
                            lut_ready      <= 0;
                            fire_step      <= 0;
                            trail_clear    <= 1;
                            spread_count   <= 2'd1;
                            spread_idx     <= 0;
                            spread_pending <= 0;
                            spread_dmg_enemy0 <= 0;
                            spread_dmg_enemy1 <= 0;
                            spread_dmg_boss   <= 0;
                        end
                    end
                end
            end

            // ===== FIRE =====
            PH_FIRE: begin
                case (fire_step)
                2'd0: begin
                    if (!is_player_turn && !current_round) begin
                        lut_angle <= (ai_angle > 7'd55) ? 7'd55 : ai_angle;
                    end else if (is_player_turn && skill_type == 2'd1 && spread_idx != 2'd0) begin
                        // For spread shots 1 and 2, adjust lut_angle
                        if (spread_idx == 2'd1) begin
                            lut_angle <= (launch_elevation + 7'd10 > 7'd90) ? 7'd90 : launch_elevation + 7'd10;
                        end else begin
                            lut_angle <= (launch_elevation >= 7'd10) ? launch_elevation - 7'd10 : 7'd0;
                        end
                    end
                    fire_step <= 2'd1;
                end
            
                2'd1: begin
                    anim_ticks <= 0;
            
                    if (!is_player_turn && current_round) begin
                        boss_attack_active <= 1'b1;
                        boss_attack_x      <= 7'd0;
                        boss_beam_hit_player  <= 1'b0;
                        proj_active        <= 1'b0;
                        game_phase         <= PH_ANIMATE;
                        fire_step          <= 0;
                    end else begin
                        proj_active    <= 1;
                        anim_ticks     <= 0;
                        trail_tick_cnt <= 0;
                        explosion_pending <= 0;  // Reset explosion flag
            
                        if (is_player_turn) begin
                            proj_fx <= {ent_px(player_entity), 8'd128};
                            proj_fy <= {ent_py(player_entity), 8'd0};
            
                            // Use the current lut_angle (which may be adjusted for spread)
                            if (reticle_right)
                                proj_vx <= $signed({1'b0, computed_power}) * $signed({1'b0, cos_val});
                            else
                                proj_vx <= -($signed({1'b0, computed_power}) * $signed({1'b0, cos_val}));
            
                            if (reticle_above)
                                proj_vy <= -($signed({1'b0, computed_power}) * $signed({1'b0, sin_val}));
                            else
                                proj_vy <=  $signed({1'b0, computed_power}) * $signed({1'b0, sin_val});
            
                            proj_x <= ent_px(player_entity);
                            proj_y <= ent_py(player_entity);
                            
                            // Store explosion radius for this shot
                            explosion_radius <= effective_blast;
                        end else begin
                            case (current_enemy_idx)
                                2'd0: begin
                                    proj_fx <= {ent_px(enemy_entity_0), 8'd128};
                                    proj_fy <= {ent_py(enemy_entity_0), 8'd0};
                                    proj_x  <= ent_px(enemy_entity_0);
                                    proj_y  <= ent_py(enemy_entity_0);
                                end
                                2'd1: begin
                                    proj_fx <= {ent_px(enemy_entity_1), 8'd128};
                                    proj_fy <= {ent_py(enemy_entity_1), 8'd0};
                                    proj_x  <= ent_px(enemy_entity_1);
                                    proj_y  <= ent_py(enemy_entity_1);
                                end
                                2'd2: begin
                                    proj_fx <= {ent_px(enemy_entity_2), 8'd128};
                                    proj_fy <= {ent_py(enemy_entity_2), 8'd0};
                                    proj_x  <= ent_px(enemy_entity_2);
                                    proj_y  <= ent_py(enemy_entity_2);
                                end
                            endcase
                            proj_vx <= -($signed({1'b0, ai_power}) * $signed({1'b0, cos_val}));
                            proj_vy <= -($signed({1'b0, ai_power}) * $signed({1'b0, sin_val}));
                            explosion_radius <= 4'd2;  // Enemy explosions are small
                        end
            
                        game_phase <= PH_ANIMATE;
                        fire_step  <= 0;
                    end
                end
                default: fire_step <= 2'd0;
                endcase
            end
            
            // ===== ANIMATE =====
            PH_ANIMATE: begin
                if (!is_player_turn && current_round && boss_attack_active) begin
                    if (tick_30hz) begin
                        anim_ticks <= anim_ticks + 1;
                        if ((boss_attack_x <= ent_px(player_entity) + {3'd0, ent_hw(player_entity)}) &&
                            (boss_attack_x + 7'd5 >= ent_px(player_entity) - {3'd0, ent_hw(player_entity)})) begin
                            boss_beam_hit_player <= 1'b1;
                        end
                        if (boss_attack_x >= 7'd95) begin
                            boss_attack_active <= 0;
                            game_phase         <= PH_RESOLVE;
                            resolve_step       <= 0;
                        end else begin
                            boss_attack_x <= boss_attack_x + 7'd5;
                        end
                    end
                end else if (tick_30hz) begin
                    proj_fx <= proj_fx + {{5{proj_vx[15]}}, proj_vx};
                    proj_fy <= proj_fy + {{5{proj_vy[15]}}, proj_vy};
                    proj_vy <= proj_vy + GRAVITY;
                    anim_ticks <= anim_ticks + 1;

                    if (!proj_fx[20] && proj_fx[14:8] < 7'd96)
                        proj_x <= proj_fx[14:8];
                    if (!proj_fy[20] && proj_fy[13:8] < 7'd64)
                        proj_y <= proj_fy[13:8];

                    if (!proj_fx[20] && proj_fx[14:8] < 7'd96 &&
                        !proj_fy[20] && proj_fy[13:8] < 7'd64) begin
                        trail_wr_en <= 1;
                        trail_wr_x  <= proj_fx[14:8];
                        trail_wr_y  <= proj_fy[13:8];
                    end

                    // Check OOB
                    if (proj_fx[20] || proj_fx[14:8] >= 7'd96 ||
                        proj_fy[20] || (!proj_fy[20] && proj_fy[13:8] >= 6'd63) ||
                        anim_ticks > 10'd300) begin
                        proj_active  <= 0;
                        game_phase   <= PH_RESOLVE;
                        resolve_step <= 0;
                    end

                    // Check entity hit for player shots
                    if (is_player_turn && !proj_fx[20] && !proj_fy[20]) begin
                        if (!current_round) begin
                            // Round 1: hit slimes using sprite bounding box
                            if (enemy_alive[0] &&
                                proj_fx[14:8] >= slime0_x && proj_fx[14:8] <= slime0_x + 7'd13 &&
                                proj_fy[13:8] >= slime_y  && proj_fy[13:8] <= slime_y  + 6'd8) begin
                                proj_active  <= 0;
                                // Store explosion center for area damage
                                explosion_center_x <= proj_fx[14:8];
                                explosion_center_y <= proj_fy[13:8];
                                explosion_pending <= 1;
                                game_phase   <= PH_RESOLVE;
                                resolve_step <= 0;
                            end
                            if (enemy_alive[1] &&
                                proj_fx[14:8] >= slime1_x && proj_fx[14:8] <= slime1_x + 7'd13 &&
                                proj_fy[13:8] >= slime_y  && proj_fy[13:8] <= slime_y  + 6'd8) begin
                                proj_active  <= 0;
                                explosion_center_x <= proj_fx[14:8];
                                explosion_center_y <= proj_fy[13:8];
                                explosion_pending <= 1;
                                game_phase   <= PH_RESOLVE;
                                resolve_step <= 0;
                            end
                        end else begin
                            // Round 2: hit boss using SPRITE bounding box
                            if (enemy_alive[0] &&
                                proj_fx[14:8] >= BOSS_SPRITE_LEFT &&
                                proj_fx[14:8] < BOSS_SPRITE_LEFT + BOSS_SPRITE_W &&
                                proj_fy[13:8] >= BOSS_SPRITE_TOP &&
                                proj_fy[13:8] < BOSS_SPRITE_TOP + BOSS_SPRITE_H) begin
                                proj_active  <= 0;
                                explosion_center_x <= proj_fx[14:8];
                                explosion_center_y <= proj_fy[13:8];
                                explosion_pending <= 1;
                                game_phase   <= PH_RESOLVE;
                                resolve_step <= 0;
                            end
                        end
                    end

                    // Check entity hit for enemy shots
                    if (!is_player_turn && !proj_fx[20] && !proj_fy[20]) begin
                        if (manhattan(proj_fx[14:8], proj_fy[13:8],
                            ent_px(player_entity), ent_py(player_entity)) <= 8'd5) begin
                            proj_active  <= 0;
                            game_phase   <= PH_RESOLVE;
                            resolve_step <= 0;
                        end
                    end
                end
            end

            // ===== RESOLVE =====
            PH_RESOLVE: begin
                trail_clear <= 1;
                case (resolve_step)
                3'd0: begin
                    next_player_hp   = real_hp_player;
                    next_enemy_hp0   = real_hp_enemy[0];
                    next_enemy_hp1   = real_hp_enemy[1];
                    next_enemy_hp2   = real_hp_enemy[2];
                    next_enemy_alive = enemy_alive;
                    player_hit_boss  <= 0;
            
                    if (is_player_turn) begin
                        if (explosion_pending) begin
                            // Handle area damage for explosive skills
                            if (skill_type == 2'd2 || skill_type == 2'd3) begin
                                // Check all enemies within explosion radius
                                if (!current_round) begin
                                    // Check slime 0
                                    if (enemy_alive[0]) begin
                                        if (manhattan(explosion_center_x, explosion_center_y, 
                                                    slime0_x + 7'd7, slime_y + 6'd4) <= {4'd0, explosion_radius}) begin
                                            if (next_enemy_hp0 <= {3'd0, skill_damage}) begin
                                                hit_event           <= 1'b1;
                                                hit_damage          <= next_enemy_hp0[7:0];
                                                next_enemy_hp0      = 9'd0;
                                                next_enemy_alive[0] = 1'b0;
                                            end else begin
                                                hit_event      <= 1'b1;
                                                hit_damage     <= {2'd0, skill_damage};
                                                next_enemy_hp0 = next_enemy_hp0 - {3'd0, skill_damage};
                                            end
                                        end
                                    end
                                    // Check slime 1
                                    if (enemy_alive[1]) begin
                                        if (manhattan(explosion_center_x, explosion_center_y,
                                                    slime1_x + 7'd7, slime_y + 6'd4) <= {4'd0, explosion_radius}) begin
                                            if (next_enemy_hp1 <= {3'd0, skill_damage}) begin
                                                hit_event           <= 1'b1;
                                                hit_damage          <= next_enemy_hp1[7:0];
                                                next_enemy_hp1      = 9'd0;
                                                next_enemy_alive[1] = 1'b0;
                                            end else begin
                                                hit_event      <= 1'b1;
                                                hit_damage     <= {2'd0, skill_damage};
                                                next_enemy_hp1 = next_enemy_hp1 - {3'd0, skill_damage};
                                            end
                                        end
                                    end
                                end else begin
                                    // Check boss
                                    if (enemy_alive[0]) begin
                                        if (manhattan(explosion_center_x, explosion_center_y,
                                                    BOSS_SPRITE_LEFT + 7'd20, BOSS_SPRITE_TOP + 6'd25) <= {4'd0, explosion_radius}) begin
                                            if (next_enemy_hp0 <= {3'd0, skill_damage}) begin
                                                hit_event           <= 1'b1;
                                                hit_damage          <= next_enemy_hp0[7:0];
                                                next_enemy_hp0      = 9'd0;
                                                next_enemy_alive[0] = 1'b0;
                                            end else begin
                                                hit_event      <= 1'b1;
                                                hit_damage     <= {2'd0, skill_damage};
                                                next_enemy_hp0 = next_enemy_hp0 - {3'd0, skill_damage};
                                            end
                                        end
                                    end
                                end
                            end else begin
                                // Single-target damage for basic and spread shots
                                if (!current_round) begin
                                    // Player attacks slime 0
                                    if (enemy_alive[0] &&
                                        proj_x >= slime0_x && proj_x <= slime0_x + 7'd13 &&
                                        proj_y >= slime_y  && proj_y <= slime_y  + 6'd8) begin
                                        if (next_enemy_hp0 <= {3'd0, skill_damage}) begin
                                            hit_event           <= 1'b1;
                                            hit_damage          <= next_enemy_hp0[7:0];
                                            next_enemy_hp0      = 9'd0;
                                            next_enemy_alive[0] = 1'b0;
                                        end else begin
                                            hit_event      <= 1'b1;
                                            hit_damage     <= {2'd0, skill_damage};
                                            next_enemy_hp0 = next_enemy_hp0 - {3'd0, skill_damage};
                                        end
                                    end
                                    // Player attacks slime 1
                                    if (enemy_alive[1] &&
                                        proj_x >= slime1_x && proj_x <= slime1_x + 7'd13 &&
                                        proj_y >= slime_y  && proj_y <= slime_y  + 6'd8) begin
                                        if (next_enemy_hp1 <= {3'd0, skill_damage}) begin
                                            hit_event           <= 1'b1;
                                            hit_damage          <= next_enemy_hp1[7:0];
                                            next_enemy_hp1      = 9'd0;
                                            next_enemy_alive[1] = 1'b0;
                                        end else begin
                                            hit_event      <= 1'b1;
                                            hit_damage     <= {2'd0, skill_damage};
                                            next_enemy_hp1 = next_enemy_hp1 - {3'd0, skill_damage};
                                        end
                                    end
                                end else begin
                                    // Player attacks boss
                                    if (enemy_alive[0] &&
                                        proj_x >= BOSS_SPRITE_LEFT &&
                                        proj_x < BOSS_SPRITE_LEFT + BOSS_SPRITE_W &&
                                        proj_y >= BOSS_SPRITE_TOP &&
                                        proj_y < BOSS_SPRITE_TOP + BOSS_SPRITE_H) begin
                                        player_hit_boss = 1;
                                        if (next_enemy_hp0 <= {3'd0, skill_damage}) begin
                                            hit_event           <= 1'b1;
                                            hit_damage          <= next_enemy_hp0[7:0];
                                            next_enemy_hp0      = 9'd0;
                                            next_enemy_alive[0] = 1'b0;
                                        end else begin
                                            hit_event      <= 1'b1;
                                            hit_damage     <= {2'd0, skill_damage};
                                            next_enemy_hp0 = next_enemy_hp0 - {3'd0, skill_damage};
                                        end
                                    end
                                end
                            end
                        end
                    end
                    else if (current_round) begin
                        // Boss beam damages player (keep existing code)
                        if (boss_beam_hit_player) begin
                            if (next_player_hp <= 9'd40) begin
                                hit_event      <= 1'b1;
                                hit_damage     <= next_player_hp[7:0];
                                next_player_hp = 9'd0;
                            end else begin
                                hit_event      <= 1'b1;
                                hit_damage     <= 8'd40;
                                next_player_hp = next_player_hp - 9'd40;
                            end
                        end
                    end
            
                    // Accumulate spread damage (keep existing code)
                    if (is_player_turn && skill_type == 2'd1) begin
                        if (!current_round) begin
                            spread_dmg_enemy0 <= spread_dmg_enemy0 + (real_hp_enemy[0] - next_enemy_hp0);
                            spread_dmg_enemy1 <= spread_dmg_enemy1 + (real_hp_enemy[1] - next_enemy_hp1);
                        end else begin
                            spread_dmg_boss <= spread_dmg_boss + (real_hp_enemy[0] - next_enemy_hp0);
                        end
                    end
            
                    real_hp_player    <= next_player_hp;
                    real_hp_enemy[0]  <= next_enemy_hp0;
                    real_hp_enemy[1]  <= next_enemy_hp1;
                    real_hp_enemy[2]  <= next_enemy_hp2;
                    enemy_alive       <= next_enemy_alive;
            
                    player_entity  <= set_hp(player_entity,
                        (next_player_hp[8:2] > 6'd63) ? 6'd63 : next_player_hp[8:2]);
                    if (!(!current_round && next_enemy_alive == 3'b000)) begin
                        enemy_entity_0 <= set_hp(enemy_entity_0,
                            current_round
                                ? scale_boss_hp_400_to_63(next_enemy_hp0)
                                : ((next_enemy_hp0 > 9'd63) ? 6'd63 : next_enemy_hp0[5:0]));
                    end
                    enemy_entity_1 <= set_hp(enemy_entity_1,
                        (next_enemy_hp1 > 9'd63) ? 6'd63 : next_enemy_hp1[5:0]);
                    enemy_entity_2 <= 46'd0;
            
                    // Check if more spread projectiles to fire
                    if (is_player_turn && skill_type == 2'd1 && spread_idx + 2'd1 < spread_count) begin
                        // More spread shots remaining
                        spread_idx   <= spread_idx + 2'd1;
                        // Reset explosion flag for next projectile
                        explosion_pending <= 0;
                        // Go back to FIRE phase for next spread projectile
                        game_phase   <= PH_FIRE;
                        fire_step    <= 0;
                        lut_ready    <= 0;
                        trail_clear  <= 1;
                        resolve_step <= 0;
                    end else begin
                        // All projectiles resolved - check win/loss (keep existing code)
                        if (next_player_hp == 9'd0) begin
                            defeat     <= 1'b1;
                            game_phase <= PH_GAMEOVER;
                        end
                        else if (next_enemy_alive == 3'b000) begin
                            if (!current_round) begin
                                current_round     <= 1'b1;
                                is_player_turn    <= 1'b1;
                                current_enemy_idx <= 2'd0;
                                player_fuel       <= 4'd10;
            
                                enemy_entity_0    <= pack_entity(TYPE_BOSS, 6'd63, 6'd30, 6'd40, 6'd0,
                                                                 7'd75, 6'd32, 4'd5, 3'd4);
                                enemy_entity_1    <= 46'd0;
                                enemy_entity_2    <= 46'd0;
                                real_hp_enemy[0]  <= 9'd400;
                                real_hp_enemy[1]  <= 9'd0;
                                real_hp_enemy[2]  <= 9'd0;
                                enemy_alive       <= 3'b001;
            
                                game_phase        <= PH_MOVE;
                            end else begin
                                victory    <= 1'b1;
                                game_phase <= PH_GAMEOVER;
                            end
                        end
                        else begin
                            if (!current_round) begin
                                is_player_turn <= 1'b1;
                                player_fuel    <= 4'd10;
                                if (player_energy + 4'd2 > 4'd15)
                                    player_energy <= 4'd15;
                                else
                                    player_energy <= player_energy + 4'd2;
                                game_phase     <= PH_MOVE;
                            end 
                            else if (is_player_turn && player_hit_boss) begin
                                // Player hit boss -> skip boss beam, go directly back to player move
                                is_player_turn <= 1'b1;
                                player_fuel    <= 4'd10;
                                boss_attack_active <= 1'b0;
                                boss_attack_x      <= 7'd0;
                                boss_beam_hit_player  <= 1'b0;
                                game_phase     <= PH_MOVE;
                            end
                            else begin
                                 game_phase <= PH_NEXTTURN;
                            end
                        end
                        resolve_step <= 0;
                    end
                end
                default: resolve_step <= 3'd0;
                endcase
            end
            
            // ===== NEXT TURN =====
            PH_NEXTTURN: begin
                if (!current_round) begin
                    is_player_turn <= 1'b1;
                    player_fuel    <= 4'd10;
                    // Energy regen +2
                    if (player_energy + 4'd2 > 4'd15)
                        player_energy <= 4'd15;
                    else
                        player_energy <= player_energy + 4'd2;
                    game_phase     <= PH_MOVE;
                end else begin
                    if (is_player_turn) begin
                        is_player_turn    <= 1'b0;
                        current_enemy_idx <= 2'd0;
                        game_phase        <= PH_MOVE;
                    end else begin
                        is_player_turn <= 1'b1;
                        player_fuel    <= 4'd10;
                        // Energy regen +2
                        if (player_energy + 4'd2 > 4'd15)
                            player_energy <= 4'd15;
                        else
                            player_energy <= player_energy + 4'd2;
                        game_phase     <= PH_MOVE;
                    end
                end
            end

            // ===== GAMEOVER =====
            PH_GAMEOVER: begin
                // Stay
            end

            default: game_phase <= PH_INIT;
            endcase
        end
    end

endmodule