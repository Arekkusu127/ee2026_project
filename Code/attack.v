`timescale 1ns / 1ps

/*
Entity data format (46 bits):
[45:44] TYPE
[43:38] HP
[37:32] DEF
[31:26] ATK
[25:20] MP
[19:13] PosX
[12:7]  PosY
[6:3]   half_width
[2:0]   half_height
*/

module attack(
    input         clk,
    input         tick,
    input         fire,
    input  [7:0]  angle,
    input  [3:0]  power,
    input  [3:0]  skill_id,
    input  [45:0] shooter_entity,
    input  [45:0] target_entity,
    input  [575:0] terrain_flat,
    output reg [6:0] proj_x,
    output reg [5:0] proj_y,
    output reg       proj_active,
    output reg       hit,
    output reg [7:0] damage
);

    // Unpack terrain
    wire [5:0] terrain [0:95];
    genvar i;
    generate
        for (i = 0; i < 96; i = i + 1) begin : unpack_t
            assign terrain[i] = terrain_flat[i*6 +: 6];
        end
    endgenerate

    // Extract entity fields
    wire [6:0] start_x   = shooter_entity[19:13];
    wire [5:0] start_y   = shooter_entity[12:7];
    wire [5:0] shoot_atk = shooter_entity[31:26];
    wire [6:0] target_x  = target_entity[19:13];
    wire [5:0] target_y  = target_entity[12:7];
    wire [3:0] tgt_hw    = target_entity[6:3];
    wire [2:0] tgt_hh    = target_entity[2:0];

    reg signed [15:0] vx;
    reg signed [15:0] vy;
    reg signed [15:0] pos_x;
    reg signed [15:0] pos_y;
    reg [7:0] step_count;
    reg       direction;

    // Simple sin/cos LUT (0..90 in steps of 10, scaled x128)
    function [7:0] sin_lut_fn;
        input [7:0] a;
        begin
            case (a / 10)
                0: sin_lut_fn = 8'd0;
                1: sin_lut_fn = 8'd22;
                2: sin_lut_fn = 8'd44;
                3: sin_lut_fn = 8'd64;
                4: sin_lut_fn = 8'd81;
                5: sin_lut_fn = 8'd98;
                6: sin_lut_fn = 8'd111;
                7: sin_lut_fn = 8'd120;
                8: sin_lut_fn = 8'd126;
                9: sin_lut_fn = 8'd128;
                default: sin_lut_fn = 8'd0;
            endcase
        end
    endfunction

    function [7:0] cos_lut_fn;
        input [7:0] a;
        begin
            cos_lut_fn = sin_lut_fn(8'd90 - a);
        end
    endfunction

    wire [7:0] s_val = sin_lut_fn(angle);
    wire [7:0] c_val = cos_lut_fn(angle);

    localparam signed [15:0] GRAVITY = 16'sd64;

    // Damage lookup per skill
    function [7:0] skill_damage_fn;
        input [3:0] sid;
        begin
            case (sid)
                4'd0:  skill_damage_fn = 8'd20;
                4'd1:  skill_damage_fn = 8'd15;
                4'd2:  skill_damage_fn = 8'd25;
                4'd3:  skill_damage_fn = 8'd35;
                4'd4:  skill_damage_fn = 8'd40;
                4'd5:  skill_damage_fn = 8'd10;
                default: skill_damage_fn = 8'd20;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (fire) begin
            direction <= (start_x < target_x) ? 1'b0 : 1'b1;
            pos_x <= {9'b0, start_x} << 8;
            pos_y <= {10'b0, start_y} << 8;
            vx <= direction ? -($signed({1'b0, power}) * $signed({1'b0, c_val}) <<< 1)
                            :  ($signed({1'b0, power}) * $signed({1'b0, c_val}) <<< 1);
            vy <= -($signed({1'b0, power}) * $signed({1'b0, s_val}) <<< 1);
            proj_active <= 1;
            hit <= 0;
            damage <= 0;
            step_count <= 0;
        end else if (proj_active && tick) begin
            pos_x <= pos_x + vx;
            pos_y <= pos_y + vy;
            vy    <= vy + GRAVITY;
            step_count <= step_count + 1;

            proj_x <= pos_x[14:8];
            proj_y <= pos_y[13:8];

            if (pos_x[14:8] > 7'd95 || pos_y[13:8] > 6'd63 || step_count > 8'd200) begin
                proj_active <= 0;
            end

            if (pos_x[14:8] < 7'd96 && pos_y[13:8] >= terrain[pos_x[14:8]]) begin
                proj_active <= 0;
            end

            // Hit detection using target entity half_width and half_height
            if (pos_x[14:8] >= target_x - {3'd0, tgt_hw} &&
                pos_x[14:8] <= target_x + {3'd0, tgt_hw} &&
                pos_y[13:8] >= target_y - {3'd0, tgt_hh} &&
                pos_y[13:8] <= target_y + {3'd0, tgt_hh}) begin
                hit <= 1;
                damage <= skill_damage_fn(skill_id);
                proj_active <= 0;
            end
        end
    end

endmodule
