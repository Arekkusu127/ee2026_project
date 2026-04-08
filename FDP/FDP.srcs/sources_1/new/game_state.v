`timescale 1ns / 1ps

module game_state #(
    parameter NUM_PLAYERS = 2,
    parameter NUM_ENEMIES = 4,
    parameter MAX_ENERGY = 16,
    parameter ENERGY_PER_TURN = 2
)(
    input clk,
    input rst,

    // Player inputs
    input fire_btn,
    input [7:0] angle_input,      // From angle selector
    input [7:0] power_input,      // From power selector

    // From attack module
    input hit_flag,
    input [1:0] hit_enemy_index,
    input [5:0] hit_damage,

    // From projectile module
    input cast_accepted,
    input spawn_pulse,
    input [4:0] energy_cost_in,
    input effect_shield_in,
    input [4:0] shield_hp_in,
    input effect_heal_in,
    input [4:0] heal_hp_in,

    // Animation done signal
    input animation_done,

    // Outputs
    output reg [2:0] phase,
    output reg [0:0] current_player,
    output reg [7:0] player_hp [0:1],
    output reg [4:0] player_energy [0:1],
    output reg [4:0] player_shield [0:1],
    output reg [7:0] player_x [0:1],
    output reg [7:0] player_y [0:1],

    output reg [7:0] enemy_hp [0:3],
    output reg [7:0] enemy_x [0:3],
    output reg [7:0] enemy_y [0:3],

    output reg game_over,
    output reg [0:0] winner,

    // To attack module
    output reg [7:0] current_angle,
    output reg [7:0] current_power,
    output reg [4:0] current_energy,
    output reg fire_trigger
);

    // Game phases
    localparam [2:0] PH_INIT       = 3'd0;
    localparam [2:0] PH_AIM        = 3'd1;
    localparam [2:0] PH_FIRE       = 3'd2;
    localparam [2:0] PH_ANIMATE    = 3'd3;
    localparam [2:0] PH_RESOLVE    = 3'd4;
    localparam [2:0] PH_NEXT_TURN  = 3'd5;
    localparam [2:0] PH_GAME_OVER  = 3'd6;

    reg fire_btn_d;
    reg [3:0] resolve_timer;

    integer k;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            phase <= PH_INIT;
            current_player <= 0;
            game_over <= 0;
            winner <= 0;
            fire_trigger <= 0;
            fire_btn_d <= 0;
            resolve_timer <= 0;
            current_angle <= 0;
            current_power <= 0;
            current_energy <= 0;

            // Initialize players
            player_hp[0] <= 8'd150;
            player_hp[1] <= 8'd150;
            player_energy[0] <= 5'd8;
            player_energy[1] <= 5'd8;
            player_shield[0] <= 5'd0;
            player_shield[1] <= 5'd0;
            player_x[0] <= 8'd10;
            player_x[1] <= 8'd85;
            player_y[0] <= 8'd0;  // Will be set by terrain
            player_y[1] <= 8'd0;

            // Initialize enemies
            enemy_hp[0] <= 8'd100;
            enemy_hp[1] <= 8'd100;
            enemy_hp[2] <= 8'd0;   // Inactive
            enemy_hp[3] <= 8'd0;   // Inactive
            enemy_x[0] <= 8'd30;
            enemy_x[1] <= 8'd65;
            enemy_x[2] <= 8'd0;
            enemy_x[3] <= 8'd0;
            enemy_y[0] <= 8'd0;
            enemy_y[1] <= 8'd0;
            enemy_y[2] <= 8'd0;
            enemy_y[3] <= 8'd0;

        end else begin
            fire_btn_d <= fire_btn;
            fire_trigger <= 0;

            case (phase)
                PH_INIT: begin
                    phase <= PH_AIM;
                end

                PH_AIM: begin
                    current_angle <= angle_input;
                    current_power <= power_input;
                    current_energy <= player_energy[current_player];

                    // Rising edge of fire button
                    if (fire_btn && !fire_btn_d) begin
                        fire_trigger <= 1;
                        phase <= PH_FIRE;
                    end
                end

                PH_FIRE: begin
                    if (cast_accepted) begin
                        // Deduct energy
                        if (player_energy[current_player] >= energy_cost_in)
                            player_energy[current_player] <=
                                player_energy[current_player] - energy_cost_in;
                        else
                            player_energy[current_player] <= 0;

                        // Apply instant effects
                        if (effect_shield_in)
                            player_shield[current_player] <=
                                player_shield[current_player] + shield_hp_in;

                        if (effect_heal_in) begin
                            if (player_hp[current_player] + heal_hp_in > 8'd150)
                                player_hp[current_player] <= 8'd150;
                            else
                                player_hp[current_player] <=
                                    player_hp[current_player] + heal_hp_in;
                        end

                        phase <= PH_ANIMATE;
                    end
                end

                PH_ANIMATE: begin
                    if (animation_done) begin
                        phase <= PH_RESOLVE;
                        resolve_timer <= 4'd5;
                    end
                end

                PH_RESOLVE: begin
                    // Apply hit damage to enemies
                    if (hit_flag) begin
                        if (enemy_hp[hit_enemy_index] > hit_damage)
                            enemy_hp[hit_enemy_index] <=
                                enemy_hp[hit_enemy_index] - hit_damage;
                        else
                            enemy_hp[hit_enemy_index] <= 0;
                    end

                    if (resolve_timer > 0) begin
                        resolve_timer <= resolve_timer - 1;
                    end else begin
                        // Check win/loss conditions
                        if (player_hp[0] == 0) begin
                            game_over <= 1;
                            winner <= 1;
                            phase <= PH_GAME_OVER;
                        end else if (player_hp[1] == 0) begin
                            game_over <= 1;
                            winner <= 0;
                            phase <= PH_GAME_OVER;
                        end else begin
                            phase <= PH_NEXT_TURN;
                        end
                    end
                end

                PH_NEXT_TURN: begin
                    current_player <= ~current_player;

                    // Grant energy at start of turn
                    if (player_energy[~current_player] + ENERGY_PER_TURN > MAX_ENERGY)
                        player_energy[~current_player] <= MAX_ENERGY;
                    else
                        player_energy[~current_player] <=
                            player_energy[~current_player] + ENERGY_PER_TURN;

                    phase <= PH_AIM;
                end

                PH_GAME_OVER: begin
                    // Stay here until reset
                end

                default: phase <= PH_INIT;
            endcase
        end
    end
endmodule
