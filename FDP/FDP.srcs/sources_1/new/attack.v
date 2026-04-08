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
    input clk,
    input signed [7:0] offset_num,
    input [2:0] projectile_type,
    input [5:0] dmg,
    input [45:0] player_data,
    input [45:0] enemy_data [0:3],
    input [5:0] terrain [0:95],

    output reg [7:0] projectile_y [0:95],
    output reg [7:0] impact_x,
    output reg [7:0] impact_y,
    output reg [7:0] impact2_x,
    output reg [7:0] impact2_y,
    output reg hit_flag,
    output reg [1:0] hit_enemy_index,
    output reg [7:0] hit_x,
    output reg [7:0] hit_y,
    output reg [5:0] damage_to_enemy [0:3]
);

    parameter g = 1;

    // Player position
    wire [7:0] x0 = player_data[23:16];
    wire [7:0] y0 = player_data[15:8];

    // Enemy data unpacking
    wire [7:0] enemy_x [0:3];
    wire [7:0] enemy_y [0:3];
    wire [3:0] enemy_hw [0:3];
    wire [3:0] enemy_hh [0:3];

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : enemy_unpack
            assign enemy_x[gi]  = enemy_data[gi][23:16];
            assign enemy_y[gi]  = enemy_data[gi][15:8];
            assign enemy_hw[gi] = enemy_data[gi][7:4];
            assign enemy_hh[gi] = enemy_data[gi][3:0];
        end
    endgenerate

    // Internal calculation variables
    integer i, e, j;
    reg signed [13:0] numerator;
    reg signed [13:0] y_calc;
    reg signed [13:0] dy;
    reg impact_detected;
    reg [7:0] ex, ey;
    reg [3:0] hw, hh;
    reg trajectory_started;

    always @(*) begin
        // Reset all outputs
        hit_flag = 0;
        hit_enemy_index = 0;
        hit_x = 0;
        hit_y = 0;
        impact_x = 0;
        impact_y = 0;
        impact2_x = 0;
        impact2_y = 0;
        impact_detected = 0;
        trajectory_started = 0;

        for (i = 0; i < 4; i = i + 1)
            damage_to_enemy[i] = 0;

        // Initialize all projectile_y to offscreen
        for (i = 0; i < 96; i = i + 1)
            projectile_y[i] = 8'd65;

        dy = $signed(offset_num);

        case (projectile_type)
            3'd0: begin
                // Straight line projectile (linear interpolation)
                for (i = 0; i < 96; i = i + 1) begin
                    if (i >= x0 && i < 96) begin
                        // Approximate /50 with (x * 5) >> 8  (≈ /51.2, ~2.4% error)
                        numerator = $signed(offset_num) * $signed({1'b0, i[7:0]} - {1'b0, x0});
                        y_calc = $signed({6'b0, y0}) + ((numerator * 5) >>> 8);

                        if (y_calc >= 65 || y_calc < 0)
                            projectile_y[i] = 8'd65;
                        else
                            projectile_y[i] = y_calc[7:0];

                        if (!impact_detected && projectile_y[i] != 8'd65 &&
                            projectile_y[i] >= terrain[i]) begin
                            impact_detected = 1;
                            impact_x = i[7:0];
                            impact_y = projectile_y[i];
                        end
                    end
                end
            end

            3'd1: begin
                // Parabolic projectile
                for (i = 0; i < 96; i = i + 1) begin
                    if (i == x0) begin
                        // Launch point
                        projectile_y[i] = y0;
                        trajectory_started = 1;
                    end else if (i > x0 && trajectory_started) begin
                        dy = dy - g;
                        y_calc = $signed({6'b0, projectile_y[i-1]}) + dy;

                        if (y_calc >= 65 || y_calc < 0)
                            projectile_y[i] = 8'd65;
                        else
                            projectile_y[i] = y_calc[7:0];

                        if (!impact_detected && projectile_y[i] != 8'd65 &&
                            projectile_y[i] >= terrain[i]) begin
                            impact_detected = 1;
                            impact_x = i[7:0];
                            impact_y = projectile_y[i];
                        end else if (impact_detected && projectile_y[i] != 8'd65 &&
                                    projectile_y[i] >= terrain[i]) begin
                            impact2_x = i[7:0];
                            impact2_y = projectile_y[i];
                        end
                    end
                end
            end

            3'd2: begin
                // Bounce projectile
                for (i = 0; i < 96; i = i + 1) begin
                    if (i == x0) begin
                        projectile_y[i] = y0;
                        trajectory_started = 1;
                    end else if (i > x0 && trajectory_started) begin
                        dy = dy - g;
                        y_calc = $signed({6'b0, projectile_y[i-1]}) + dy;

                        if (y_calc >= 65 || y_calc < 0)
                            projectile_y[i] = 8'd65;
                        else
                            projectile_y[i] = y_calc[7:0];

                        if (!impact_detected && projectile_y[i] != 8'd65 &&
                            projectile_y[i] >= terrain[i]) begin
                            impact_detected = 1;
                            impact_x = i[7:0];
                            impact_y = projectile_y[i];
                            // Bounce: reverse and halve vertical velocity
                            dy = -(dy >>> 1);
                        end
                    end
                end
            end

            default: begin
                // No trajectory
            end
        endcase

        // Enemy hit detection
        for (e = 0; e < 4; e = e + 1) begin
            ex = enemy_x[e];
            ey = enemy_y[e];
            hw = enemy_hw[e];
            hh = enemy_hh[e];

            for (j = 0; j < 96; j = j + 1) begin
                if (j >= (ex - hw) && j <= (ex + hw) &&
                    projectile_y[j] != 8'd65 &&
                    projectile_y[j] >= (ey - hh) &&
                    projectile_y[j] <= (ey + hh)) begin
                    if (!hit_flag) begin
                        hit_flag = 1;
                        hit_enemy_index = e[1:0];
                        damage_to_enemy[e] = dmg;
                        hit_x = j[7:0];
                        hit_y = projectile_y[j];
                    end
                end
            end
        end
    end
endmodule
