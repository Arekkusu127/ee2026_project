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
    input wire step_en,          // physics step tick
    input wire cast_req,         // fire button pressed
    input wire impact_trigger,   // signal from physics: flare/seed hit ground
    input wire [15:0] sw,        // Basys 3 switches: sw[i] selects skill i+1, none = basic(0)
    input wire [4:0] energy_in,  // current energy from game state

    // Handshake
    output reg cast_accepted,    // one-cycle pulse: cast was accepted
    output reg spawn_pulse,      // one-cycle pulse: spawn a projectile with below metadata
    output reg [4:0] energy_after,
    output reg can_cast,         // combinational: enough energy and sequencer idle
    output reg [4:0] energy_cost,// combinational: cost of currently selected skill

    // Projectile metadata (valid on spawn_pulse)
    output reg [2:0] projectile_kind,
    output reg signed [8:0] angle_offset_deg,
    output reg [7:0] damage,
    output reg [3:0] speed_scale_q2,    // Q2 fixed point: 4 = 1.0x
    output reg signed [18:0] gravity_q10,
    output reg straight_line,
    output reg ignore_terrain,
    output reg ignore_entities,
    output reg pierce_entities_once,    // passes through first entity hit
    output reg pierce_terrain_once,     // phases through first terrain hit
    output reg bounce_terrain_once,     // reflects off first terrain hit
    output reg explode_on_impact,
    output reg [4:0] aoe_radius,
    output reg [7:0] aoe_base_damage,
    output reg spawn_from_sky,
    output reg signed [7:0] spawn_x_offset,
    output reg [5:0] spawn_y_start,

    // Special effect flags (game state manager handles these)
    output reg effect_shield,           // this cast grants shield HP
    output reg [4:0] shield_hp,
    output reg effect_heal,             // this cast heals
    output reg [4:0] heal_hp,
    output reg effect_fire_zone,        // impact creates fire zone
    output reg [3:0] fire_zone_width,
    output reg [2:0] fire_zone_turns,
    output reg [7:0] fire_zone_dpt,     // damage per turn
    output reg effect_gravity_pull,     // impact creates gravity pull
    output reg [4:0] pull_radius,
    output reg [4:0] pull_duration_steps,
    output reg effect_chain_lightning,
    output reg [3:0] chain_range,
    output reg [1:0] chain_count,
    output reg [7:0] chain_damage
);

    // =========================================================================
    // Skill IDs (0-16, matching energy cost)
    // =========================================================================
    localparam [4:0] SK_ARROW       = 5'd0;   // Basic Arrow
    localparam [4:0] SK_QUICK       = 5'd1;   // Quick Shot
    localparam [4:0] SK_SCATTER     = 5'd2;   // Scatter Shot (Shotgun)
    localparam [4:0] SK_BOUNCE      = 5'd3;   // Bouncing Arrow
    localparam [4:0] SK_VOLLEY      = 5'd4;   // Triple Volley (Burst)
    localparam [4:0] SK_SHIELD      = 5'd5;   // Shield Charm
    localparam [4:0] SK_RAIN        = 5'd6;   // Arrow Rain (Stream)
    localparam [4:0] SK_PIERCE      = 5'd7;   // Piercing Arrow
    localparam [4:0] SK_FIREPOT     = 5'd8;   // Fire Pot (Bomb)
    localparam [4:0] SK_HEAL        = 5'd9;   // Healing Herb
    localparam [4:0] SK_STORM       = 5'd10;  // Arrow Storm (Airstrike)
    localparam [4:0] SK_GREEK       = 5'd11;  // Greek Fire (Napalm)
    localparam [4:0] SK_SPIRIT      = 5'd12;  // Spirit Arrow (Ghost Shell)
    localparam [4:0] SK_CHAIN       = 5'd13;  // Chain Lightning
    localparam [4:0] SK_BLOSSOM     = 5'd14;  // Blossom Burst (Flower)
    localparam [4:0] SK_BLACKHOLE   = 5'd15;  // Black Hole Arrow
    localparam [4:0] SK_SNIPE       = 5'd16;  // Straight Snipe

    // =========================================================================
    // Projectile kind archetypes
    // =========================================================================
    localparam [2:0] K_ARROW  = 3'd0;  // standard arrow trajectory
    localparam [2:0] K_BOMB   = 3'd1;  // AoE on impact
    localparam [2:0] K_FLARE  = 3'd2;  // marker projectile (no damage)
    localparam [2:0] K_SEED   = 3'd3;  // marker for flower/chain
    localparam [2:0] K_SNIPE  = 3'd4;  // straight line, no gravity
    localparam [2:0] K_EFFECT = 3'd5;  // no projectile (shield/heal)

    // =========================================================================
    // Physics constants (Q10 fixed-point gravity)
    // =========================================================================
    localparam signed [18:0] G_NORMAL  = 19'sd128;   // standard gravity
    localparam signed [18:0] G_HEAVY   = 19'sd166;   // 1.3x gravity
    localparam signed [18:0] G_REVERSE = -19'sd128;   // inverted
    localparam signed [18:0] G_NONE    = 19'sd0;      // no gravity

    // =========================================================================
    // Spread/offset constants
    // =========================================================================
    localparam signed [8:0] SPREAD_8   = 9'sd8;
    localparam signed [8:0] SPREAD_5   = 9'sd5;
    localparam signed [8:0] SPREAD_3   = 9'sd3;
    localparam signed [7:0] STORM_GAP  = 8'sd4;    // airstrike horizontal gap

    // =========================================================================
    // Switch decode: one-hot to skill ID
    // No switch active = basic arrow (cost 0)
    // sw[0] = skill 1 (Quick Shot), sw[15] = skill 16 (Snipe)
    // =========================================================================
    reg [4:0] skill_sel;

    always @(*) begin
        if      (sw[0])  skill_sel = 5'd1;   // Quick Shot
        else if (sw[1])  skill_sel = 5'd2;   // Scatter Shot
        else if (sw[2])  skill_sel = 5'd3;   // Bouncing Arrow
        else if (sw[3])  skill_sel = 5'd4;   // Triple Volley
        else if (sw[4])  skill_sel = 5'd5;   // Shield Charm
        else if (sw[5])  skill_sel = 5'd6;   // Arrow Rain
        else if (sw[6])  skill_sel = 5'd7;   // Piercing Arrow
        else if (sw[7])  skill_sel = 5'd8;   // Fire Pot
        else if (sw[8])  skill_sel = 5'd9;   // Healing Herb
        else if (sw[9])  skill_sel = 5'd10;  // Arrow Storm
        else if (sw[10]) skill_sel = 5'd11;  // Greek Fire
        else if (sw[11]) skill_sel = 5'd12;  // Spirit Arrow
        else if (sw[12]) skill_sel = 5'd13;  // Chain Lightning
        else if (sw[13]) skill_sel = 5'd14;  // Blossom Burst
        else if (sw[14]) skill_sel = 5'd15;  // Black Hole Arrow
        else if (sw[15]) skill_sel = 5'd16;  // Straight Snipe
        else             skill_sel = 5'd0;   // Basic Arrow (no switch)
    end


    // =========================================================================
    // Cost lookup (cost = skill ID, by design)
    // =========================================================================
    reg [4:0] cost_now;
    reg cast_ok;

    always @(*) begin
        cost_now = skill_sel;  // cost equals skill ID (0-16)
        energy_cost = cost_now;
        cast_ok = (!seq_active) && (energy_in >= cost_now);
        can_cast = cast_ok;
    end

    // =========================================================================
    // Sequencer state
    // =========================================================================
    reg cast_req_d;
    reg seq_active;
    reg [4:0] seq_skill;
    reg [3:0] shots_left;
    reg [4:0] wait_ctr;
    reg [1:0] seq_stage;       // 0=init, 1=wait_impact, 2=spawn_children
    reg [2:0] sub_phase;       // sub-index within multi-shot patterns

    // =========================================================================
    // Default metadata helper task
    // =========================================================================
    task set_defaults;
    begin
        projectile_kind      <= K_ARROW;
        angle_offset_deg     <= 9'sd0;
        damage               <= 8'd0;
        speed_scale_q2       <= 4'd4;   // 1.0x
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

    // =========================================================================
    // Main sequential logic
    // =========================================================================
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
            set_defaults;
        end else begin
            // Defaults each cycle
            cast_req_d    <= cast_req;
            cast_accepted <= 1'b0;
            spawn_pulse   <= 1'b0;
            energy_after  <= energy_in;
            set_defaults;

            // =================================================================
            // Cast acceptance on rising edge of cast_req
            // =================================================================
            if (cast_req && !cast_req_d && cast_ok) begin
                cast_accepted <= 1'b1;
                seq_active    <= 1'b1;
                seq_skill     <= skill_sel;
                seq_stage     <= 2'd0;
                wait_ctr      <= 5'd0;
                sub_phase     <= 3'd0;

                // Energy transaction
                if (skill_sel == SK_ARROW || skill_sel == SK_QUICK) begin
                    // Basic and Quick Shot regen 1 energy
                    energy_after <= (energy_in >= 5'd16) ? 5'd16 : (energy_in + 5'd1);
                end else begin
                    energy_after <= energy_in - cost_now;
                end

                // Set shots_left for multi-shot skills
                case (skill_sel)
                    SK_ARROW:     shots_left <= 4'd1;
                    SK_QUICK:     shots_left <= 4'd1;
                    SK_SCATTER:   shots_left <= 4'd3;
                    SK_BOUNCE:    shots_left <= 4'd1;
                    SK_VOLLEY:    shots_left <= 4'd3;
                    SK_SHIELD:    shots_left <= 4'd0;  // no projectile
                    SK_RAIN:      shots_left <= 4'd5;
                    SK_PIERCE:    shots_left <= 4'd1;
                    SK_FIREPOT:   shots_left <= 4'd1;
                    SK_HEAL:      shots_left <= 4'd0;  // no projectile
                    SK_STORM:     shots_left <= 4'd1;  // flare first
                    SK_GREEK:     shots_left <= 4'd1;
                    SK_SPIRIT:    shots_left <= 4'd1;
                    SK_CHAIN:     shots_left <= 4'd1;
                    SK_BLOSSOM:   shots_left <= 4'd1;  // seed first
                    SK_BLACKHOLE: shots_left <= 4'd1;
                    SK_SNIPE:     shots_left <= 4'd1;
                    default:      shots_left <= 4'd1;
                endcase

                // Instant-effect skills (no projectile needed)
                if (skill_sel == SK_SHIELD) begin
                    spawn_pulse   <= 1'b1;
                    projectile_kind <= K_EFFECT;
                    effect_shield <= 1'b1;
                    shield_hp     <= 5'd6;
                    seq_active    <= 1'b0;
                end
                if (skill_sel == SK_HEAL) begin
                    spawn_pulse   <= 1'b1;
                    projectile_kind <= K_EFFECT;
                    effect_heal   <= 1'b1;
                    heal_hp       <= 5'd5;
                    seq_active    <= 1'b0;
                end
            end

            // =================================================================
            // Sequencer execution on step_en ticks
            // =================================================================
            if (seq_active && step_en) begin
                if (wait_ctr != 5'd0) begin
                    wait_ctr <= wait_ctr - 5'd1;
                end else begin
                    case (seq_skill)

                        // ---------------------------------------------------------
                        // Cost 0: Basic Arrow — 3 dmg, +1 energy
                        // ---------------------------------------------------------
                        SK_ARROW: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_ARROW;
                            damage           <= 8'd3;
                            speed_scale_q2   <= 4'd4;   // 1.0x
                            gravity_q10      <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            seq_active       <= 1'b0;
                        end

                        // ---------------------------------------------------------
                        // Cost 1: Quick Shot — 4 dmg, +1 energy, faster
                        // ---------------------------------------------------------
                        SK_QUICK: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_ARROW;
                            damage           <= 8'd4;
                            speed_scale_q2   <= 4'd5;   // 1.25x
                            gravity_q10      <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            seq_active       <= 1'b0;
                        end

                        // ---------------------------------------------------------
                        // Cost 2: Scatter Shot — 3 arrows, ±8° spread, 2 dmg each
                        // ---------------------------------------------------------
                        SK_SCATTER: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_ARROW;
                            damage           <= 8'd2;
                            speed_scale_q2   <= 4'd4;
                            gravity_q10      <= G_NORMAL;
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

                        // ---------------------------------------------------------
                        // Cost 3: Bouncing Arrow — 1 terrain bounce, 5 dmg
                        // ---------------------------------------------------------
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

                        // ---------------------------------------------------------
                        // Cost 4: Triple Volley — 3 sequential arrows, 2 dmg each
                        // ---------------------------------------------------------
                        SK_VOLLEY: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_ARROW;
                            damage           <= 8'd2;
                            speed_scale_q2   <= 4'd4;
                            gravity_q10      <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            angle_offset_deg <= 9'sd0;

                            shots_left <= shots_left - 4'd1;
                            if (shots_left == 4'd1)
                                seq_active <= 1'b0;
                            else
                                wait_ctr <= 5'd2;  // slight delay between shots
                        end

                        // ---------------------------------------------------------
                        // Cost 5: Shield Charm — handled at cast acceptance (instant)
                        // Cost 9: Healing Herb — handled at cast acceptance (instant)
                        // ---------------------------------------------------------

                        // ---------------------------------------------------------
                        // Cost 6: Arrow Rain — 5 arrows, angles 0°,±5°,±3°, 2 dmg each
                        // ---------------------------------------------------------
                        SK_RAIN: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_ARROW;
                            damage           <= 8'd2;
                            speed_scale_q2   <= 4'd4;
                            gravity_q10      <= G_NORMAL;
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

                        // ---------------------------------------------------------
                        // Cost 7: Piercing Arrow — passes through first entity, 4 dmg/hit
                        // ---------------------------------------------------------
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

                        // ---------------------------------------------------------
                        // Cost 8: Fire Pot — 1.3x gravity, 6 dmg center, 6px AoE
                        // ---------------------------------------------------------
                        SK_FIREPOT: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_BOMB;
                            damage           <= 8'd6;
                            speed_scale_q2   <= 4'd3;   // 0.75x (heavier, slower)
                            gravity_q10      <= G_HEAVY;
                            explode_on_impact <= 1'b1;
                            aoe_radius       <= 5'd6;
                            aoe_base_damage  <= 8'd6;
                            seq_active       <= 1'b0;
                        end

                        // ---------------------------------------------------------
                        // Cost 10: Arrow Storm — flare then 3 vertical bombs
                        // ---------------------------------------------------------
                        SK_STORM: begin
                            case (seq_stage)
                                2'd0: begin
                                    // Fire flare projectile
                                    spawn_pulse      <= 1'b1;
                                    projectile_kind  <= K_FLARE;
                                    damage           <= 8'd0;
                                    speed_scale_q2   <= 4'd4;
                                    gravity_q10      <= G_NORMAL;
                                    explode_on_impact <= 1'b0;
                                    seq_stage        <= 2'd1;
                                    shots_left       <= 4'd3;
                                end
                                2'd1: begin
                                    // Wait for flare to hit ground
                                    if (impact_trigger)
                                        seq_stage <= 2'd2;
                                end
                                2'd2: begin
                                    // Spawn 3 sky bombs with horizontal offsets
                                    spawn_pulse      <= 1'b1;
                                    projectile_kind  <= K_BOMB;
                                    damage           <= 8'd4;
                                    speed_scale_q2   <= 4'd0;
                                    gravity_q10      <= G_HEAVY;
                                    explode_on_impact <= 1'b1;
                                    aoe_radius       <= 5'd3;
                                    aoe_base_damage  <= 8'd4;
                                    spawn_from_sky   <= 1'b1;
                                    spawn_y_start    <= 6'd0;

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

                        // ---------------------------------------------------------
                        // Cost 11: Greek Fire — arrow that creates 12px fire zone, 3 turns
                        // ---------------------------------------------------------
                        SK_GREEK: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_BOMB;
                            damage           <= 8'd0;       // no direct hit damage
                            speed_scale_q2   <= 4'd4;
                            gravity_q10      <= G_NORMAL;
                            explode_on_impact <= 1'b1;
                            effect_fire_zone <= 1'b1;
                            fire_zone_width  <= 4'd12;
                            fire_zone_turns  <= 3'd3;
                            fire_zone_dpt    <= 8'd3;
                            seq_active       <= 1'b0;
                        end

                        // ---------------------------------------------------------
                        // Cost 12: Spirit Arrow — inverted gravity, phases terrain, 7 dmg
                        // ---------------------------------------------------------
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

                        // ---------------------------------------------------------
                        // Cost 13: Chain Lightning — 6 primary, arcs to 2 within 15px
                        // ---------------------------------------------------------
                        SK_CHAIN: begin
                            spawn_pulse            <= 1'b1;
                            projectile_kind        <= K_SEED;  // uses seed as marker
                            damage                 <= 8'd6;
                            speed_scale_q2         <= 4'd5;    // 1.25x fast
                            gravity_q10            <= G_NORMAL;
                            explode_on_impact      <= 1'b1;
                            effect_chain_lightning <= 1'b1;
                            chain_range            <= 4'd15;
                            chain_count            <= 2'd2;
                            chain_damage           <= 8'd4;
                            seq_active             <= 1'b0;
                        end

                        // ---------------------------------------------------------
                        // Cost 14: Blossom Burst — seed, then 6 hex-pattern explosions
                        // ---------------------------------------------------------
                        SK_BLOSSOM: begin
                            case (seq_stage)
                                2'd0: begin
                                    // Fire seed projectile
                                    spawn_pulse      <= 1'b1;
                                    projectile_kind  <= K_SEED;
                                    damage           <= 8'd0;
                                    speed_scale_q2   <= 4'd4;
                                    gravity_q10      <= G_NORMAL;
                                    explode_on_impact <= 1'b0;
                                    seq_stage        <= 2'd1;
                                    shots_left       <= 4'd6;
                                end
                                2'd1: begin
                                    // Wait for seed impact
                                    if (impact_trigger)
                                        seq_stage <= 2'd2;
                                end
                                2'd2: begin
                                    // 6 explosions in hex pattern around impact
                                    spawn_pulse      <= 1'b1;
                                    projectile_kind  <= K_BOMB;
                                    damage           <= 8'd3;
                                    speed_scale_q2   <= 4'd2;   // short range burst
                                    gravity_q10      <= G_NORMAL;
                                    explode_on_impact <= 1'b1;
                                    aoe_radius       <= 5'd3;
                                    aoe_base_damage  <= 8'd3;

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

                        // ---------------------------------------------------------
                        // Cost 15: Black Hole Arrow — 10px pull, then 8 dmg detonation
                        // ---------------------------------------------------------
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
                            pull_duration_steps  <= 5'd15;  // ~1.5s at 10 steps/s
                            seq_active           <= 1'b0;
                        end

                        // ---------------------------------------------------------
                        // Cost 16: Straight Snipe — no gravity, pierces all, 10 dmg/hit
                        // ---------------------------------------------------------
                        SK_SNIPE: begin
                            spawn_pulse      <= 1'b1;
                            projectile_kind  <= K_SNIPE;
                            damage           <= 8'd10;
                            speed_scale_q2   <= 4'd8;   // 2.0x
                            gravity_q10      <= G_NONE;
                            straight_line    <= 1'b1;
                            ignore_terrain   <= 1'b1;
                            ignore_entities  <= 1'b1;   // passes through everything, damages all
                            explode_on_impact <= 1'b0;
                            seq_active       <= 1'b0;
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