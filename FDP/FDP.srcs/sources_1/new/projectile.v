`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qiang Jiayuan
// 
// Create Date: 28.03.2026 01:43:14
// Design Name: 
// Module Name: projectile
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Weapon selection, energy management, and projectile sequencer.
//              17 weapons (cost 0-16), selected via 16 switches
//              or default to basic (cost 0) when no switch active.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module projectile (
    input wire clk,
    input wire rst,
    input wire step_en,
    input wire cast_req,
    input wire impact_trigger,
    input wire [15:0] sw,
    input wire [4:0] energy_in,

    output reg cast_accepted,
    output reg spawn_pulse,
    output reg [4:0] energy_after,
    output reg can_cast,
    output reg [4:0] energy_cost,

    output reg [2:0] projectile_kind,
    output reg signed [8:0] angle_offset_deg,
    output reg [7:0] damage,
    output reg [3:0] speed_scale_q2,
    output reg signed [18:0] gravity_q10,
    output reg straight_line,
    output reg ignore_terrain,
    output reg ignore_entities,
    output reg pierce_entities_once,
    output reg pierce_terrain_once,
    output reg bounce_terrain_once,
    output reg explode_on_impact,
    output reg [4:0] aoe_radius,
    output reg [7:0] aoe_base_damage,
    output reg spawn_from_sky,
    output reg signed [7:0] spawn_x_offset,
    output reg [5:0] spawn_y_start,

    output reg effect_shield,
    output reg [4:0] shield_hp,
    output reg effect_heal,
    output reg [4:0] heal_hp,
    output reg effect_fire_zone,
    output reg [3:0] fire_zone_width,
    output reg [2:0] fire_zone_turns,
    output reg [7:0] fire_zone_dpt,
    output reg effect_gravity_pull,
    output reg [4:0] pull_radius,
    output reg [4:0] pull_duration_steps,
    output reg effect_chain_lightning,
    output reg [3:0] chain_range,
    output reg [1:0] chain_count,
    output reg [7:0] chain_damage
);

    // Skill IDs
    localparam [4:0] SK_ARROW     = 5'd0;
    localparam [4:0] SK_QUICK     = 5'd1;
    localparam [4:0] SK_SCATTER   = 5'd2;
    localparam [4:0] SK_BOUNCE    = 5'd3;
    localparam [4:0] SK_VOLLEY    = 5'd4;
    localparam [4:0] SK_SHIELD    = 5'd5;
    localparam [4:0] SK_RAIN      = 5'd6;
    localparam [4:0] SK_PIERCE    = 5'd7;
    localparam [4:0] SK_FIREPOT   = 5'd8;
    localparam [4:0] SK_HEAL      = 5'd9;
    localparam [4:0] SK_STORM     = 5'd10;
    localparam [4:0] SK_GREEK     = 5'd11;
    localparam [4:0] SK_SPIRIT    = 5'd12;
    localparam [4:0] SK_CHAIN     = 5'd13;
    localparam [4:0] SK_BLOSSOM   = 5'd14;
    localparam [4:0] SK_BLACKHOLE = 5'd15;
    localparam [4:0] SK_SNIPE     = 5'd16;

    // Projectile archetypes
    localparam [2:0] K_ARROW  = 3'd0;
    localparam [2:0] K_BOMB   = 3'd1;
    localparam [2:0] K_FLARE  = 3'd2;
    localparam [2:0] K_SEED   = 3'd3;
    localparam [2:0] K_SNIPE  = 3'd4;
    localparam [2:0] K_EFFECT = 3'd5;

    // Gravity constants (Q10 fixed-point)
    localparam signed [18:0] G_NORMAL  =  19'sd128;
    localparam signed [18:0] G_HEAVY   =  19'sd166;
    localparam signed [18:0] G_REVERSE = -19'sd128;
    localparam signed [18:0] G_NONE    =  19'sd0;

    // Spread constants
    localparam signed [8:0] SPREAD_8  = 9'sd8;
    localparam signed [8:0] SPREAD_5  = 9'sd5;
    localparam signed [8:0] SPREAD_3  = 9'sd3;
    localparam signed [7:0] STORM_GAP = 8'sd4;

    // Switch decode
    reg [4:0] skill_sel;
    always @(*) begin
        casez (sw)
            16'b???????????????1: skill_sel = 5'd1;
            16'b??????????????1?: skill_sel = 5'd2;
            16'b?????????????1??: skill_sel = 5'd3;
            16'b????????????1???: skill_sel = 5'd4;
            16'b???????????1????: skill_sel = 5'd5;
            16'b??????????1?????: skill_sel = 5'd6;
            16'b?????????1??????: skill_sel = 5'd7;
            16'b????????1???????: skill_sel = 5'd8;
            16'b???????1????????: skill_sel = 5'd9;
            16'b??????1?????????: skill_sel = 5'd10;
            16'b?????1??????????: skill_sel = 5'd11;
            16'b????1???????????: skill_sel = 5'd12;
            16'b???1????????????: skill_sel = 5'd13;
            16'b??1?????????????: skill_sel = 5'd14;
            16'b?1??????????????: skill_sel = 5'd15;
            16'b1???????????????: skill_sel = 5'd16;
            default:              skill_sel = 5'd0;
        endcase
    end

    // Cost and can_cast
    reg [4:0] cost_now;
    reg cast_ok;
    reg seq_active;

    always @(*) begin
        cost_now = skill_sel;
        energy_cost = cost_now;
        cast_ok = (!seq_active) && (energy_in >= cost_now);
        can_cast = cast_ok;
    end

    // Sequencer state
    reg cast_req_d;
    reg [4:0] seq_skill;
    reg [3:0] shots_left;
    reg [4:0] wait_ctr;
    reg [1:0] seq_stage;
    reg [2:0] sub_phase;

    // Reset all projectile metadata to safe defaults
    task clear_metadata;
    begin
        projectile_kind      <= K_ARROW;
        angle_offset_deg     <= 9'sd0;
        damage               <= 8'd0;
        speed_scale_q2       <= 4'd4;
        gravity_q10          <= G_NORMAL;
        straight_line        <= 1'b0;
        ignore_terrain       <= 1'b0;
        ignore_entities      <= 1'b0;
        pierce_entities_once <= 1'b0;
        pierce_terrain_once  <= 1'b0;
        bounce_terrain_once  <= 1'b0;
        explode_on_impact    <= 1'b0;
        aoe_radius           <= 5'd0;
        aoe_base_damage      <= 8'd0;
        spawn_from_sky       <= 1'b0;
        spawn_x_offset       <= 8'sd0;
        spawn_y_start        <= 6'd0;
        effect_shield        <= 1'b0;
        shield_hp            <= 5'd0;
        effect_heal          <= 1'b0;
        heal_hp              <= 5'd0;
        effect_fire_zone     <= 1'b0;
        fire_zone_width      <= 4'd0;
        fire_zone_turns      <= 3'd0;
        fire_zone_dpt        <= 8'd0;
        effect_gravity_pull  <= 1'b0;
        pull_radius          <= 5'd0;
        pull_duration_steps  <= 5'd0;
        effect_chain_lightning <= 1'b0;
        chain_range          <= 4'd0;
        chain_count          <= 2'd0;
        chain_damage         <= 8'd0;
    end
    endtask

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cast_req_d     <= 1'b0;
            seq_active     <= 1'b0;
            seq_skill      <= SK_ARROW;
            shots_left     <= 4'd0;
            wait_ctr       <= 5'd0;
            seq_stage      <= 2'd0;
            sub_phase      <= 3'd0;
            cast_accepted  <= 1'b0;
            spawn_pulse    <= 1'b0;
            energy_after   <= 5'd0;
            clear_metadata;
        end else begin
            cast_req_d    <= cast_req;
            cast_accepted <= 1'b0;
            spawn_pulse   <= 1'b0;
            energy_after  <= energy_in;
            clear_metadata;

            // ---- Cast acceptance on rising edge ----
            if (cast_req && !cast_req_d && cast_ok) begin
                cast_accepted <= 1'b1;
                seq_active    <= 1'b1;
                seq_skill     <= skill_sel;
                seq_stage     <= 2'd0;
                wait_ctr      <= 5'd0;
                sub_phase     <= 3'd0;

                if (skill_sel == SK_ARROW || skill_sel == SK_QUICK)
                    energy_after <= (energy_in >= 5'd16) ? 5'd16 : (energy_in + 5'd1);
                else
                    energy_after <= energy_in - cost_now;

                case (skill_sel)
                    SK_ARROW:     shots_left <= 4'd1;
                    SK_QUICK:     shots_left <= 4'd1;
                    SK_SCATTER:   shots_left <= 4'd3;
                    SK_BOUNCE:    shots_left <= 4'd1;
                    SK_VOLLEY:    shots_left <= 4'd3;
                    SK_SHIELD:    shots_left <= 4'd0;
                    SK_RAIN:      shots_left <= 4'd5;
                    SK_PIERCE:    shots_left <= 4'd1;
                    SK_FIREPOT:   shots_left <= 4'd1;
                    SK_HEAL:      shots_left <= 4'd0;
                    SK_STORM:     shots_left <= 4'd1;
                    SK_GREEK:     shots_left <= 4'd1;
                    SK_SPIRIT:    shots_left <= 4'd1;
                    SK_CHAIN:     shots_left <= 4'd1;
                    SK_BLOSSOM:   shots_left <= 4'd1;
                    SK_BLACKHOLE: shots_left <= 4'd1;
                    SK_SNIPE:     shots_left <= 4'd1;
                    default:      shots_left <= 4'd1;
                endcase

                // Instant effects (no projectile)
                if (skill_sel == SK_SHIELD) begin
                    spawn_pulse     <= 1'b1;
                    projectile_kind <= K_EFFECT;
                    effect_shield   <= 1'b1;
                    shield_hp       <= 5'd6;
                    seq_active      <= 1'b0;
                end
                if (skill_sel == SK_HEAL) begin
                    spawn_pulse     <= 1'b1;
                    projectile_kind <= K_EFFECT;
                    effect_heal     <= 1'b1;
                    heal_hp         <= 5'd5;
                    seq_active      <= 1'b0;
                end
            end

            // ---- Sequencer on step_en ----
            if (seq_active && step_en) begin
                if (wait_ctr != 5'd0) begin
                    wait_ctr <= wait_ctr - 5'd1;
                end else begin
                    case (seq_skill)

                        SK_ARROW: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_ARROW;
                            damage            <= 8'd3;
                            speed_scale_q2    <= 4'd4;
                            gravity_q10       <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            seq_active        <= 1'b0;
                        end

                        SK_QUICK: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_ARROW;
                            damage            <= 8'd4;
                            speed_scale_q2    <= 4'd5;
                            gravity_q10       <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            seq_active        <= 1'b0;
                        end

                        SK_SCATTER: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_ARROW;
                            damage            <= 8'd2;
                            speed_scale_q2    <= 4'd4;
                            gravity_q10       <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            case (shots_left)
                                4'd3: angle_offset_deg <= -SPREAD_8;
                                4'd2: angle_offset_deg <=  9'sd0;
                                default: angle_offset_deg <= SPREAD_8;
                            endcase
                            shots_left <= shots_left - 4'd1;
                            if (shots_left == 4'd1)
                                seq_active <= 1'b0;
                        end

                        SK_BOUNCE: begin
                            spawn_pulse         <= 1'b1;
                            projectile_kind     <= K_ARROW;
                            damage              <= 8'd5;
                            speed_scale_q2      <= 4'd4;
                            gravity_q10         <= G_NORMAL;
                            bounce_terrain_once <= 1'b1;
                            explode_on_impact   <= 1'b1;
                            seq_active          <= 1'b0;
                        end

                        SK_VOLLEY: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_ARROW;
                            damage            <= 8'd2;
                            speed_scale_q2    <= 4'd4;
                            gravity_q10       <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            shots_left <= shots_left - 4'd1;
                            if (shots_left == 4'd1)
                                seq_active <= 1'b0;
                            else
                                wait_ctr <= 5'd2;
                        end

                        SK_SHIELD, SK_HEAL: begin
                            // Already handled at cast acceptance
                            seq_active <= 1'b0;
                        end

                        SK_RAIN: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_ARROW;
                            damage            <= 8'd2;
                            speed_scale_q2    <= 4'd4;
                            gravity_q10       <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            case (shots_left)
                                4'd5: angle_offset_deg <=  9'sd0;
                                4'd4: angle_offset_deg <=  SPREAD_5;
                                4'd3: angle_offset_deg <= -SPREAD_5;
                                4'd2: angle_offset_deg <=  SPREAD_3;
                                default: angle_offset_deg <= -SPREAD_3;
                            endcase
                            shots_left <= shots_left - 4'd1;
                            if (shots_left == 4'd1)
                                seq_active <= 1'b0;
                            else
                                wait_ctr <= 5'd1;
                        end

                        SK_PIERCE: begin
                            spawn_pulse          <= 1'b1;
                            projectile_kind      <= K_ARROW;
                            damage               <= 8'd4;
                            speed_scale_q2       <= 4'd4;
                            gravity_q10          <= G_NORMAL;
                            pierce_entities_once <= 1'b1;
                            explode_on_impact    <= 1'b1;
                            seq_active           <= 1'b0;
                        end

                        SK_FIREPOT: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_BOMB;
                            damage            <= 8'd6;
                            speed_scale_q2    <= 4'd3;
                            gravity_q10       <= G_HEAVY;
                            explode_on_impact <= 1'b1;
                            aoe_radius        <= 5'd6;
                            aoe_base_damage   <= 8'd6;
                            seq_active        <= 1'b0;
                        end

                        SK_STORM: begin
                            case (seq_stage)
                                2'd0: begin
                                    spawn_pulse       <= 1'b1;
                                    projectile_kind   <= K_FLARE;
                                    damage            <= 8'd0;
                                    speed_scale_q2    <= 4'd4;
                                    gravity_q10       <= G_NORMAL;
                                    explode_on_impact <= 1'b0;
                                    seq_stage         <= 2'd1;
                                    shots_left        <= 4'd3;
                                end
                                2'd1: begin
                                    if (impact_trigger)
                                        seq_stage <= 2'd2;
                                end
                                2'd2: begin
                                    spawn_pulse       <= 1'b1;
                                    projectile_kind   <= K_BOMB;
                                    damage            <= 8'd4;
                                    speed_scale_q2    <= 4'd0;
                                    gravity_q10       <= G_HEAVY;
                                    explode_on_impact <= 1'b1;
                                    aoe_radius        <= 5'd3;
                                    aoe_base_damage   <= 8'd4;
                                    spawn_from_sky    <= 1'b1;
                                    spawn_y_start     <= 6'd0;
                                    case (shots_left)
                                        4'd3: spawn_x_offset <= -STORM_GAP;
                                        4'd2: spawn_x_offset <=  8'sd0;
                                        default: spawn_x_offset <= STORM_GAP;
                                    endcase
                                    shots_left <= shots_left - 4'd1;
                                    if (shots_left == 4'd1)
                                        seq_active <= 1'b0;
                                    else
                                        wait_ctr <= 5'd2;
                                end
                                default: seq_active <= 1'b0;
                            endcase
                        end

                        SK_GREEK: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_BOMB;
                            damage            <= 8'd0;
                            speed_scale_q2    <= 4'd4;
                            gravity_q10       <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            effect_fire_zone  <= 1'b1;
                            fire_zone_width   <= 4'd12;
                            fire_zone_turns   <= 3'd3;
                            fire_zone_dpt     <= 8'd3;
                            seq_active        <= 1'b0;
                        end

                        SK_SPIRIT: begin
                            spawn_pulse         <= 1'b1;
                            projectile_kind     <= K_ARROW;
                            damage              <= 8'd7;
                            speed_scale_q2      <= 4'd4;
                            gravity_q10         <= G_REVERSE;
                            pierce_terrain_once <= 1'b1;
                            explode_on_impact   <= 1'b1;
                            seq_active          <= 1'b0;
                        end

                        SK_CHAIN: begin
                            spawn_pulse            <= 1'b1;
                            projectile_kind        <= K_SEED;
                            damage                 <= 8'd6;
                            speed_scale_q2         <= 4'd5;
                            gravity_q10            <= G_NORMAL;
                            explode_on_impact      <= 1'b1;
                            effect_chain_lightning <= 1'b1;
                            chain_range            <= 4'd15;
                            chain_count            <= 2'd2;
                            chain_damage           <= 8'd4;
                            seq_active             <= 1'b0;
                        end

                        SK_BLOSSOM: begin
                            case (seq_stage)
                                2'd0: begin
                                    spawn_pulse       <= 1'b1;
                                    projectile_kind   <= K_SEED;
                                    damage            <= 8'd0;
                                    speed_scale_q2    <= 4'd4;
                                    gravity_q10       <= G_NORMAL;
                                    explode_on_impact <= 1'b0;
                                    seq_stage         <= 2'd1;
                                    shots_left        <= 4'd6;
                                end
                                2'd1: begin
                                    if (impact_trigger)
                                        seq_stage <= 2'd2;
                                end
                                2'd2: begin
                                    spawn_pulse       <= 1'b1;
                                    projectile_kind   <= K_BOMB;
                                    damage            <= 8'd3;
                                    speed_scale_q2    <= 4'd2;
                                    gravity_q10       <= G_NORMAL;
                                    explode_on_impact <= 1'b1;
                                    aoe_radius        <= 5'd3;
                                    aoe_base_damage   <= 8'd3;
                                    case (shots_left)
                                        4'd6: angle_offset_deg <=  9'sd0;
                                        4'd5: angle_offset_deg <=  9'sd60;
                                        4'd4: angle_offset_deg <=  9'sd120;
                                        4'd3: angle_offset_deg <=  9'sd180;
                                        4'd2: angle_offset_deg <= -9'sd120;
                                        default: angle_offset_deg <= -9'sd60;
                                    endcase
                                    shots_left <= shots_left - 4'd1;
                                    if (shots_left == 4'd1)
                                        seq_active <= 1'b0;
                                    else
                                        wait_ctr <= 5'd1;
                                end
                                default: seq_active <= 1'b0;
                            endcase
                        end

                        SK_BLACKHOLE: begin
                            spawn_pulse          <= 1'b1;
                            projectile_kind      <= K_BOMB;
                            damage               <= 8'd8;
                            speed_scale_q2       <= 4'd4;
                            gravity_q10          <= G_NORMAL;
                            explode_on_impact    <= 1'b1;
                            aoe_radius           <= 5'd10;
                            aoe_base_damage      <= 8'd8;
                            effect_gravity_pull  <= 1'b1;
                            pull_radius          <= 5'd10;
                            pull_duration_steps  <= 5'd15;
                            seq_active           <= 1'b0;
                        end

                        SK_SNIPE: begin
                            spawn_pulse       <= 1'b1;
                            projectile_kind   <= K_SNIPE;
                            damage            <= 8'd10;
                            speed_scale_q2    <= 4'd8;
                            gravity_q10       <= G_NONE;
                            straight_line     <= 1'b1;
                            ignore_terrain    <= 1'b1;
                            ignore_entities   <= 1'b1;
                            explode_on_impact <= 1'b0;
                            seq_active        <= 1'b0;
                        end

                        default: begin
                            seq_active <= 1'b0;
                        end
                    endcase
                end
            end
        end
    end
endmodule
