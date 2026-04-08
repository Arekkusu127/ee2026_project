`timescale 1ns / 1ps
/*
Description: Attack module for projectile motion and hit detection
WHW
*/

/*
00    000000  0000  000000  0000  00000000  00000000  0000  0000     
TYPE  HP      DEF   ATK     MP    PosX      PosY      Xvar  Yvar  
0             8         16          24        32        40     
*/

/*
Entity data format (46 bits):
[45:44] TYPE
[43:38] HP
[37:32] DEF
[31:26] ATK
[25:20] MP
[23:16] PosX
[15:8]  PosY
[7:4]   half_width
[3:0]   half_height
*/

module attack(
    input         clk,
    input         tick,        // 30 Hz animation
    input         fire,
    input  [7:0]  angle,
    input  [3:0]  power,
    input  [3:0]  skill_id,
    input  [6:0]  start_x,
    input  [5:0]  start_y,
    input  [6:0]  target_x,
    input  [5:0]  target_y,
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

    // Sine/cosine lookup (simplified: 8 entries for 0-90 degrees)
    // Scaled by 128. sin(0)=0, sin(45)=91, sin(90)=128
    // We use angle >> 3 as index (0..11 roughly)

    reg signed [15:0] vx;   // velocity x (scaled x256)
    reg signed [15:0] vy;   // velocity y (scaled x256)
    reg signed [15:0] pos_x; // position x (scaled x256)
    reg signed [15:0] pos_y; // position y (scaled x256)
    reg [7:0] step_count;
    reg       direction;     // 0 = fire right, 1 = fire left

    // Approximate sin/cos using shift tricks
    // sin(angle) ~ angle * 91 / 64 for small angles (very rough)
    // For simplicity: vx = power * cos_approx, vy = power * sin_approx

    // Simple LUT for sin values (0..90 in steps of 10)
    function [7:0] sin_lut;
        input [7:0] a;
        begin
            case (a / 10)
                0: sin_lut = 8'd0;    // sin(0) * 128
                1: sin_lut = 8'd22;   // sin(10) * 128
                2: sin_lut = 8'd44;   // sin(20)
                3: sin_lut = 8'd64;   // sin(30)
                4: sin_lut = 8'd81;   // sin(40)
                5: sin_lut = 8'd98;   // sin(50)
                6: sin_lut = 8'd111;  // sin(60)
                7: sin_lut = 8'd120;  // sin(70)
                8: sin_lut = 8'd126;  // sin(80)
                9: sin_lut = 8'd128;  // sin(90)
                default: sin_lut = 8'd0;
            endcase
        end
    endfunction

    function [7:0] cos_lut;
        input [7:0] a;
        begin
            cos_lut = sin_lut(8'd90 - a);
        end
    endfunction

    wire [7:0] sin_val = sin_lut(angle);
    wire [7:0] cos_val = cos_lut(angle);

    // Gravity (scaled): ~2 per tick in y (scaled x256 = 512)
    localparam signed [15:0] GRAVITY = 16'sd64;

    // Damage lookup per skill
    function [7:0] skill_damage;
        input [3:0] sid;
        begin
            case (sid)
                4'd0:  skill_damage = 8'd20;  // basic shot
                4'd1:  skill_damage = 8'd15;  // scatter (per hit)
                4'd2:  skill_damage = 8'd25;  // volley
                4'd3:  skill_damage = 8'd35;  // firepot
                4'd4:  skill_damage = 8'd40;  // snipe
                4'd5:  skill_damage = 8'd10;  // light shot
                default: skill_damage = 8'd20;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (fire) begin
            direction <= (start_x < target_x) ? 1'b0 : 1'b1;
            pos_x <= {9'b0, start_x} << 8;
            pos_y <= {10'b0, start_y} << 8;
            // vx = power * cos / 128, but keep scaled x256
            // vx = power * cos_val * 2
            vx <= direction ? -($signed({1'b0, power}) * $signed({1'b0, cos_val}) <<< 1)
                            :  ($signed({1'b0, power}) * $signed({1'b0, cos_val}) <<< 1);
            vy <= -($signed({1'b0, power}) * $signed({1'b0, sin_val}) <<< 1); // upward is negative
            proj_active <= 1;
            hit <= 0;
            damage <= 0;
            step_count <= 0;
        end else if (proj_active && tick) begin
            pos_x <= pos_x + vx;
            pos_y <= pos_y + vy;
            vy    <= vy + GRAVITY;
            step_count <= step_count + 1;

            // Update visible position
            proj_x <= pos_x[14:8];
            proj_y <= pos_y[13:8];

            // Boundary check
            if (pos_x[14:8] > 7'd95 || pos_y[13:8] > 6'd63 || step_count > 8'd200) begin
                proj_active <= 0;
            end

            // Terrain collision
            if (pos_x[14:8] < 7'd96 && pos_y[13:8] >= terrain[pos_x[14:8]]) begin
                proj_active <= 0;
            end

            // Target hit detection (within 3 pixels)
            if (pos_x[14:8] >= target_x - 2 && pos_x[14:8] <= target_x + 2 &&
                pos_y[13:8] >= target_y - 3 && pos_y[13:8] <= target_y + 1) begin
                hit <= 1;
                damage <= skill_damage(skill_id);
                proj_active <= 0;
            end
        end
    end

endmodule
