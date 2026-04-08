`timescale 1ns / 1ps

/*
Entity data format (46 bits):
[45:44] TYPE       - 00=player, 01=minion, 10=boss
[43:38] HP         - 6 bits (0-63, scaled: real_hp = val * hp_scale)
[37:32] DEF        - 6 bits
[31:26] ATK        - 6 bits
[25:20] MP         - 6 bits
[19:13] PosX       - 7 bits (0-95)
[12:7]  PosY       - 6 bits (0-63)
[6:3]   half_width - 4 bits
[2:0]   half_height- 3 bits
*/

module game_state(
    input         clk,
    input         rst,
    input         fire_btn,
    input         angle_up,
    input         angle_down,
    input         power_up,
    input         power_down,
    input  [3:0]  skill_sel,
    // terrain RAM port A
    output reg [6:0]  terrain_rd_addr_a,
    input      [5:0]  terrain_rd_data_a,
    output reg        terrain_wr_en,
    output reg [6:0]  terrain_wr_addr,
    output reg [5:0]  terrain_wr_data,
    // outputs
    output reg [2:0]  game_phase,
    output [6:0]      player_x,
    output [5:0]      player_y,
    output reg [8:0]  player_hp,
    output reg [6:0]  player_angle,
    output reg [3:0]  player_power,
    output reg [3:0]  player_energy,
    output reg        current_round,
    // Entity data outputs (46 bits each)
    output reg [45:0] player_entity,
    output reg [45:0] enemy_entity_0,
    output reg [45:0] enemy_entity_1,
    output reg [45:0] enemy_entity_2,
    output reg [2:0]  enemy_alive,
    output reg        proj_active,
    output reg [6:0]  proj_x,
    output reg [5:0]  proj_y,
    output reg        victory,
    output reg        defeat
);

    // Game phases
    localparam PH_INIT     = 3'd0;
    localparam PH_AIM      = 3'd1;
    localparam PH_FIRE     = 3'd2;
    localparam PH_ANIMATE  = 3'd3;
    localparam PH_RESOLVE  = 3'd4;
    localparam PH_NEXTTURN = 3'd5;
    localparam PH_GAMEOVER = 3'd6;

    // Entity TYPE codes
    localparam TYPE_PLAYER = 2'b00;
    localparam TYPE_MINION = 2'b01;
    localparam TYPE_BOSS   = 2'b10;

    // ---- Entity field helpers ----
    // Pack entity: {TYPE[1:0], HP[5:0], DEF[5:0], ATK[5:0], MP[5:0], PosX[6:0], PosY[5:0], hw[3:0], hh[2:0]}
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

    // Extract fields from entity
    function [1:0] ent_type;   input [45:0] e; ent_type   = e[45:44]; endfunction
    function [5:0] ent_hp;     input [45:0] e; ent_hp     = e[43:38]; endfunction
    function [5:0] ent_def;    input [45:0] e; ent_def    = e[37:32]; endfunction
    function [5:0] ent_atk;    input [45:0] e; ent_atk    = e[31:26]; endfunction
    function [5:0] ent_mp;     input [45:0] e; ent_mp     = e[25:20]; endfunction
    function [6:0] ent_px;     input [45:0] e; ent_px     = e[19:13]; endfunction
    function [5:0] ent_py;     input [45:0] e; ent_py     = e[12:7];  endfunction
    function [3:0] ent_hw;     input [45:0] e; ent_hw     = e[6:3];   endfunction
    function [2:0] ent_hh;     input [45:0] e; ent_hh     = e[2:0];   endfunction

    // Write a single field back
    // For HP: bits [43:38]
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

    // Expose player position for top-level
    assign player_x = ent_px(player_entity);
    assign player_y = ent_py(player_entity);

    // HP scaling: player real_hp = entity_hp * 4 (max 63*4=252 >= 200)
    //             minion real_hp = entity_hp * 1 (max 63 >= 50)
    //             boss   real_hp = entity_hp * 8 (max 63*8=504 >= 400)
    localparam [3:0] HP_SCALE_PLAYER = 4'd4;
    localparam [3:0] HP_SCALE_MINION = 4'd1;
    localparam [3:0] HP_SCALE_BOSS   = 4'd8;

    // Internal real HP tracking (full precision)
    reg [8:0] real_hp_player;
    reg [8:0] real_hp_enemy [0:2];

    // Fixed-point projectile (x256)
    reg signed [20:0] proj_fx, proj_fy;
    reg signed [15:0] proj_vx, proj_vy;
    localparam signed [15:0] GRAVITY = 16'sd10;

    // 30 Hz tick from 100 MHz
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

    // LFSR
    wire [15:0] rng;
    lfsr16 lfsr_inst (.clk(clk), .rst(rst), .rng(rng));

    // Sin/Cos LUT
    reg  [6:0] lut_angle;
    wire [8:0] sin_val, cos_val;
    sin_lut sin_inst (.angle(lut_angle), .sin_val(sin_val));
    cos_lut cos_inst (.angle(lut_angle), .cos_val(cos_val));

    // Turn management
    reg        is_player_turn;
    reg [1:0]  current_enemy_idx;

    // Skill data
    reg [5:0]  skill_damage;
    reg [3:0]  skill_blast;

    // Animation tick counter
    reg [9:0]  anim_ticks;

    // AI think delay
    reg [5:0]  ai_delay;

    // Terrain init counter
    reg [6:0]  init_col;
    reg [2:0]  init_step;

    // Resolve sub-state
    reg [2:0]  resolve_step;
    reg signed [7:0] blast_dx;

    // Fire direction
    reg        fire_dir_right;

    // AI computed angle/power
    reg [6:0]  ai_angle;
    reg [3:0]  ai_power;

    // LUT ready flag
    reg        lut_ready;

    // Keep player_hp output synced with real_hp_player
    always @(*) begin
        player_hp = real_hp_player;
    end

    // ---- Skill decoder ----
    always @(*) begin
        case (skill_sel)
            4'd0: begin skill_damage = 6'd25; skill_blast = 4'd3; end // Normal
            4'd1: begin skill_damage = 6'd15; skill_blast = 4'd2; end // Scatter
            4'd2: begin skill_damage = 6'd40; skill_blast = 4'd2; end // Snipe
            4'd3: begin skill_damage = 6'd35; skill_blast = 4'd5; end // Firepot
            4'd4: begin skill_damage = 6'd60; skill_blast = 4'd7; end // Nuke
            default: begin skill_damage = 6'd25; skill_blast = 4'd3; end
        endcase
    end

    // Manhattan distance function
    function [7:0] manhattan;
        input [6:0] x1;
        input [5:0] y1;
        input [6:0] x2;
        input [5:0] y2;
        reg [6:0] dx;
        reg [5:0] dy;
        begin
            dx = (x1 > x2) ? (x1 - x2) : (x2 - x1);
            dy = (y1 > y2) ? (y1 - y2) : (y2 - y1);
            manhattan = {1'b0, dx} + {2'b00, dy};
        end
    endfunction

    // Terrain height computation for init
    reg [5:0] computed_terrain;
    always @(*) begin
        if (!current_round) begin
            if (init_col < 7'd24)
                computed_terrain = 6'd48 - (init_col[2:0] < 4 ? init_col[2:0] : (3'd7 - init_col[2:0]));
            else if (init_col < 7'd48)
                computed_terrain = 6'd44 - (init_col[2:0] < 4 ? init_col[2:0] : (3'd7 - init_col[2:0]));
            else if (init_col < 7'd72)
                computed_terrain = 6'd46 - (init_col[2:0] < 4 ? init_col[2:0] : (3'd7 - init_col[2:0]));
            else
                computed_terrain = 6'd48 - (init_col[2:0] < 4 ? init_col[2:0] : (3'd7 - init_col[2:0]));
        end else begin
            if (init_col >= 7'd40 && init_col <= 7'd56)
                computed_terrain = 6'd56;
            else
                computed_terrain = 6'd48;
        end
    end

    // Helper: get entity for current enemy index
    function [45:0] get_enemy_entity;
        input [1:0] idx;
        begin
            case (idx)
                2'd0: get_enemy_entity = enemy_entity_0;
                2'd1: get_enemy_entity = enemy_entity_1;
                2'd2: get_enemy_entity = enemy_entity_2;
                default: get_enemy_entity = 46'd0;
            endcase
        end
    endfunction

    // ====== MAIN FSM ======
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            game_phase      <= PH_INIT;
            real_hp_player  <= 9'd200;
            player_angle    <= 7'd45;
            player_power    <= 4'd8;
            player_energy   <= 4'd12;
            current_round   <= 0;
            enemy_alive     <= 3'b111;
            proj_active     <= 0;
            proj_x          <= 0;
            proj_y          <= 0;
            proj_fx         <= 0;
            proj_fy         <= 0;
            proj_vx         <= 0;
            proj_vy         <= 0;
            victory         <= 0;
            defeat          <= 0;
            is_player_turn  <= 1;
            current_enemy_idx <= 0;
            terrain_wr_en   <= 0;
            init_col        <= 0;
            init_step       <= 0;
            anim_ticks      <= 0;
            ai_delay        <= 0;
            resolve_step    <= 0;
            blast_dx        <= 0;
            fire_dir_right  <= 1;
            lut_angle       <= 0;
            lut_ready       <= 0;
            ai_angle        <= 7'd45;
            ai_power        <= 4'd7;

            // Player entity: TYPE=00, HP=50(x4=200), DEF=5, ATK=25, MP=12, X=10, Y=0, hw=2, hh=1
            player_entity  <= pack_entity(TYPE_PLAYER, 6'd50, 6'd5, 6'd25, 6'd12, 7'd10, 6'd0, 4'd2, 3'd1);

            // Round 1 enemies: minions at x=55,70,85 - HP=50(x1=50), DEF=2, ATK=15, MP=0, hw=1, hh=1
            enemy_entity_0 <= pack_entity(TYPE_MINION, 6'd50, 6'd2, 6'd15, 6'd0, 7'd55, 6'd0, 4'd1, 3'd1);
            enemy_entity_1 <= pack_entity(TYPE_MINION, 6'd50, 6'd2, 6'd15, 6'd0, 7'd70, 6'd0, 4'd1, 3'd1);
            enemy_entity_2 <= pack_entity(TYPE_MINION, 6'd50, 6'd2, 6'd15, 6'd0, 7'd85, 6'd0, 4'd1, 3'd1);

            real_hp_enemy[0] <= 9'd50;
            real_hp_enemy[1] <= 9'd50;
            real_hp_enemy[2] <= 9'd50;
        end else begin
            terrain_wr_en <= 0;

            case (game_phase)

            // ===== INIT: Write terrain to RAM =====
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
                    // Place player on terrain
                    player_entity <= set_pos(player_entity,
                        ent_px(player_entity),
                        (terrain_rd_data_a >= 6'd4) ? terrain_rd_data_a - 6'd3 : 6'd1);
                    terrain_rd_addr_a <= ent_px(enemy_entity_0);
                    init_step <= 3'd4;
                end
                3'd4: begin
                    if (current_round)
                        enemy_entity_0 <= set_pos(enemy_entity_0,
                            ent_px(enemy_entity_0),
                            (terrain_rd_data_a >= 6'd6) ? terrain_rd_data_a - 6'd5 : 6'd1);
                    else
                        enemy_entity_0 <= set_pos(enemy_entity_0,
                            ent_px(enemy_entity_0),
                            (terrain_rd_data_a >= 6'd4) ? terrain_rd_data_a - 6'd3 : 6'd1);
                    if (!current_round) begin
                        terrain_rd_addr_a <= ent_px(enemy_entity_1);
                        init_step <= 3'd5;
                    end else begin
                        init_step <= 3'd7;
                    end
                end
                3'd5: begin
                    enemy_entity_1 <= set_pos(enemy_entity_1,
                        ent_px(enemy_entity_1),
                        (terrain_rd_data_a >= 6'd4) ? terrain_rd_data_a - 6'd3 : 6'd1);
                    terrain_rd_addr_a <= ent_px(enemy_entity_2);
                    init_step <= 3'd6;
                end
                3'd6: begin
                    enemy_entity_2 <= set_pos(enemy_entity_2,
                        ent_px(enemy_entity_2),
                        (terrain_rd_data_a >= 6'd4) ? terrain_rd_data_a - 6'd3 : 6'd1);
                    init_step <= 3'd7;
                end
                3'd7: begin
                    game_phase      <= PH_AIM;
                    is_player_turn  <= 1;
                    current_enemy_idx <= 0;
                    init_step       <= 0;
                    init_col        <= 0;
                end
                default: init_step <= 3'd0;
                endcase
            end

            // ===== AIM =====
            PH_AIM: begin
                if (is_player_turn) begin
                    if (angle_up   && player_angle < 7'd90) player_angle <= player_angle + 1;
                    if (angle_down && player_angle > 7'd0)  player_angle <= player_angle - 1;
                    if (power_up   && player_power < 4'd15) player_power <= player_power + 1;
                    if (power_down && player_power > 4'd1)  player_power <= player_power - 1;
                    if (fire_btn) begin
                        fire_dir_right <= 1;
                        lut_angle      <= player_angle;
                        game_phase     <= PH_FIRE;
                        lut_ready      <= 0;
                    end
                end else begin
                    if (ai_delay < 6'd30) begin
                        if (tick_30hz) ai_delay <= ai_delay + 1;
                    end else begin
                        ai_delay       <= 0;
                        fire_dir_right <= 0;
                        if (!current_round) begin
                            ai_angle <= 7'd40 + {3'd0, rng[3:0]};
                            ai_power <= 4'd6  + {2'd0, rng[5:4]};
                        end else begin
                            ai_angle <= 7'd38 + {4'd0, rng[2:0]};
                            ai_power <= 4'd8  + {2'd0, rng[4:3]};
                        end
                        game_phase <= PH_FIRE;
                        lut_ready  <= 0;
                    end
                end
            end

            // ===== FIRE =====
            PH_FIRE: begin
                if (!lut_ready) begin
                    if (!is_player_turn) begin
                        if (!current_round)
                            lut_angle <= (ai_angle > 7'd55) ? 7'd55 : ai_angle;
                        else
                            lut_angle <= (ai_angle > 7'd45) ? 7'd45 : ai_angle;
                        if (!current_round) begin
                            if (ai_power > 4'd9) ai_power <= 4'd9;
                        end else begin
                            if (ai_power > 4'd11) ai_power <= 4'd11;
                        end
                    end
                    lut_ready <= 1;
                end else begin
                    proj_active <= 1;
                    anim_ticks  <= 0;

                    if (is_player_turn) begin
                        proj_fx <= {ent_px(player_entity), 8'd128};
                        proj_fy <= {ent_py(player_entity), 8'd0};
                        proj_vx <= $signed({1'b0, player_power}) * $signed({1'b0, cos_val});
                        proj_vy <= -($signed({1'b0, player_power}) * $signed({1'b0, sin_val}));
                        proj_x  <= ent_px(player_entity);
                        proj_y  <= ent_py(player_entity);
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
                            default: begin
                                proj_fx <= 0;
                                proj_fy <= 0;
                            end
                        endcase
                        proj_vx <= -($signed({1'b0, ai_power}) * $signed({1'b0, cos_val}));
                        proj_vy <= -($signed({1'b0, ai_power}) * $signed({1'b0, sin_val}));
                    end

                    game_phase <= PH_ANIMATE;
                    lut_ready  <= 0;
                end
            end

            // ===== ANIMATE =====
            PH_ANIMATE: begin
                if (tick_30hz) begin
                    proj_fx <= proj_fx + {{5{proj_vx[15]}}, proj_vx};
                    proj_fy <= proj_fy + {{5{proj_vy[15]}}, proj_vy};
                    proj_vy <= proj_vy + GRAVITY;
                    anim_ticks <= anim_ticks + 1;

                    if (!proj_fx[20] && proj_fx[14:8] < 7'd96)
                        proj_x <= proj_fx[14:8];
                    if (!proj_fy[20] && proj_fy[13:8] < 6'd64)
                        proj_y <= proj_fy[13:8];

                    if (!proj_fx[20])
                        terrain_rd_addr_a <= proj_fx[14:8];

                    if (proj_fx[20] || proj_fx[14:8] >= 7'd96 ||
                        (!proj_fy[20] && proj_fy[13:8] >= 6'd63)) begin
                        proj_active <= 0;
                        game_phase  <= PH_RESOLVE;
                        resolve_step <= 0;
                    end
                    else if (anim_ticks > 1 && !proj_fy[20] && proj_fy[13:8] >= terrain_rd_data_a) begin
                        proj_active <= 0;
                        game_phase  <= PH_RESOLVE;
                        resolve_step <= 0;
                    end
                end
            end

            // ===== RESOLVE =====
            PH_RESOLVE: begin
                case (resolve_step)
                3'd0: begin
                    if (is_player_turn) begin
                        // Player -> enemies: use ATK from player entity for base, but skill_damage overrides
                        if (enemy_alive[0] && manhattan(proj_x, proj_y, ent_px(enemy_entity_0), ent_py(enemy_entity_0)) <= {4'd0, skill_blast}) begin
                            if (real_hp_enemy[0] <= {3'd0, skill_damage})
                                real_hp_enemy[0] <= 9'd0;
                            else
                                real_hp_enemy[0] <= real_hp_enemy[0] - {3'd0, skill_damage};
                        end
                        if (enemy_alive[1] && manhattan(proj_x, proj_y, ent_px(enemy_entity_1), ent_py(enemy_entity_1)) <= {4'd0, skill_blast}) begin
                            if (real_hp_enemy[1] <= {3'd0, skill_damage})
                                real_hp_enemy[1] <= 9'd0;
                            else
                                real_hp_enemy[1] <= real_hp_enemy[1] - {3'd0, skill_damage};
                        end
                        if (enemy_alive[2] && manhattan(proj_x, proj_y, ent_px(enemy_entity_2), ent_py(enemy_entity_2)) <= {4'd0, skill_blast}) begin
                            if (real_hp_enemy[2] <= {3'd0, skill_damage})
                                real_hp_enemy[2] <= 9'd0;
                            else
                                real_hp_enemy[2] <= real_hp_enemy[2] - {3'd0, skill_damage};
                        end
                    end else begin
                        // Enemy -> player: damage based on entity ATK field
                        if (manhattan(proj_x, proj_y, ent_px(player_entity), ent_py(player_entity)) <= 8'd5) begin
                            if (!current_round) begin
                                // Minion ATK: 15 damage
                                if (real_hp_player <= 9'd15)
                                    real_hp_player <= 9'd0;
                                else
                                    real_hp_player <= real_hp_player - 9'd15;
                            end else begin
                                // Boss ATK: 30 damage
                                if (real_hp_player <= 9'd30)
                                    real_hp_player <= 9'd0;
                                else
                                    real_hp_player <= real_hp_player - 9'd30;
                            end
                        end
                    end

                    // Update alive flags
                    if (real_hp_enemy[0] == 9'd0) enemy_alive[0] <= 1'b0;
                    if (real_hp_enemy[1] == 9'd0) enemy_alive[1] <= 1'b0;
                    if (real_hp_enemy[2] == 9'd0) enemy_alive[2] <= 1'b0;

                    // Sync entity HP fields (scaled down for entity format)
                    // Player: real_hp/4, clamped to 6 bits
                    player_entity <= set_hp(player_entity,
                        (real_hp_player[8:2] > 6'd63) ? 6'd63 : real_hp_player[8:2]);
                    enemy_entity_0 <= set_hp(enemy_entity_0,
                        (real_hp_enemy[0] > 9'd63) ? 6'd63 : real_hp_enemy[0][5:0]);
                    enemy_entity_1 <= set_hp(enemy_entity_1,
                        (real_hp_enemy[1] > 9'd63) ? 6'd63 : real_hp_enemy[1][5:0]);
                    enemy_entity_2 <= set_hp(enemy_entity_2,
                        (real_hp_enemy[2] > 9'd63) ? 6'd63 : real_hp_enemy[2][5:0]);

                    blast_dx     <= -$signed({4'd0, skill_blast});
                    resolve_step <= 3'd1;
                end
                3'd1: begin
                    if (blast_dx <= $signed({4'd0, skill_blast})) begin
                        if (($signed({1'b0, proj_x}) + blast_dx) >= 0 &&
                            ($signed({1'b0, proj_x}) + blast_dx) < 96) begin
                            terrain_rd_addr_a <= proj_x + blast_dx[6:0];
                            resolve_step <= 3'd2;
                        end else begin
                            blast_dx     <= blast_dx + 1;
                            resolve_step <= 3'd1;
                        end
                    end else begin
                        resolve_step <= 3'd3;
                    end
                end
                3'd2: begin
                    if (terrain_rd_data_a < 6'd62) begin
                        terrain_wr_en   <= 1;
                        terrain_wr_addr <= proj_x + blast_dx[6:0];
                        terrain_wr_data <= terrain_rd_data_a + 6'd1;
                    end
                    blast_dx     <= blast_dx + 1;
                    resolve_step <= 3'd1;
                end
                3'd3: begin
                    if (real_hp_player == 9'd0) begin
                        defeat     <= 1;
                        game_phase <= PH_GAMEOVER;
                    end else if (enemy_alive == 3'b000) begin
                        if (!current_round) begin
                            current_round   <= 1;
                            player_energy   <= 4'd12;
                            // Update player entity MP
                            player_entity[25:20] <= 6'd12;
                            // Boss: TYPE=10, HP=50(x8=400), DEF=8, ATK=30, MP=0, X=80, Y=0, hw=3, hh=2
                            enemy_entity_0 <= pack_entity(TYPE_BOSS, 6'd50, 6'd8, 6'd30, 6'd0, 7'd80, 6'd0, 4'd3, 3'd2);
                            enemy_entity_1 <= 46'd0;
                            enemy_entity_2 <= 46'd0;
                            real_hp_enemy[0] <= 9'd400;
                            real_hp_enemy[1] <= 9'd0;
                            real_hp_enemy[2] <= 9'd0;
                            enemy_alive    <= 3'b001;
                            init_col       <= 0;
                            init_step      <= 0;
                            game_phase     <= PH_INIT;
                        end else begin
                            victory    <= 1;
                            game_phase <= PH_GAMEOVER;
                        end
                    end else begin
                        game_phase <= PH_NEXTTURN;
                    end
                    resolve_step <= 0;
                end
                default: resolve_step <= 3'd0;
                endcase
            end

            // ===== NEXT TURN =====
            PH_NEXTTURN: begin
                if (is_player_turn) begin
                    is_player_turn <= 0;
                    if (!current_round) begin
                        if (enemy_alive[0])      current_enemy_idx <= 2'd0;
                        else if (enemy_alive[1]) current_enemy_idx <= 2'd1;
                        else if (enemy_alive[2]) current_enemy_idx <= 2'd2;
                        else                     is_player_turn <= 1;
                    end else begin
                        current_enemy_idx <= 2'd0;
                    end
                    game_phase <= PH_AIM;
                end else begin
                    if (!current_round) begin
                        if (current_enemy_idx == 2'd0 && (enemy_alive[1] || enemy_alive[2])) begin
                            if (enemy_alive[1])  current_enemy_idx <= 2'd1;
                            else                 current_enemy_idx <= 2'd2;
                            game_phase <= PH_AIM;
                        end else if (current_enemy_idx == 2'd1 && enemy_alive[2]) begin
                            current_enemy_idx <= 2'd2;
                            game_phase <= PH_AIM;
                        end else begin
                            is_player_turn <= 1;
                            game_phase <= PH_AIM;
                        end
                    end else begin
                        is_player_turn <= 1;
                        game_phase <= PH_AIM;
                    end
                end
            end

            // ===== GAMEOVER =====
            PH_GAMEOVER: begin
                // Stay here
            end

            default: game_phase <= PH_INIT;
            endcase
        end
    end

endmodule
