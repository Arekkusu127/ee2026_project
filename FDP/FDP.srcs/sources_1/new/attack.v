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

module attack(
    input clk,
    input signed [7:0] offset_num,
    input [2:0] projectile_type,
    input [45:0] data [4:0],
    input [5:0] terrain [0:95],
    output [7:0] projectile_y [0:95],
    output [7:0] impact_x, impact_y
    output reg hit_flag,
    output reg [1:0] hit_enemy_index,
    output reg [7:0] hit_x, hit_y
    );
    integer i = 0;
    parameter g = 1;

    wire [7:0] x = data[0][23:16];
    wire [7:0] y = data[0][15: 8];

    reg signed [13:0] numerator;
    reg signed [13:0] y_calc;
    reg signed [13:0] dy;

    reg impact_detected = 0;

    // Unpack Enemy positions
    wire [7:0] enemy_x  [0:3];
    wire [7:0] enemy_y  [0:3];
    wire [3:0] enemy_hw [0:3];  // x half-width
    wire [3:0] enemy_hh [0:3];  // y half-height

    assign enemy_x[0]  = enemy_0[23:16];
    assign enemy_y[0]  = enemy_0[15:8];
    assign enemy_hw[0] = enemy_0[7:4];
    assign enemy_hh[0] = enemy_0[3:0];

    assign enemy_x[1]  = enemy_1[23:16];
    assign enemy_y[1]  = enemy_1[15:8];
    assign enemy_hw[1] = enemy_1[7:4];
    assign enemy_hh[1] = enemy_1[3:0];

    assign enemy_x[2]  = enemy_2[23:16];
    assign enemy_y[2]  = enemy_2[15:8];
    assign enemy_hw[2] = enemy_2[7:4];
    assign enemy_hh[2] = enemy_2[3:0];

    assign enemy_x[3]  = enemy_3[23:16];
    assign enemy_y[3]  = enemy_3[15:8];
    assign enemy_hw[3] = enemy_3[7:4];
    assign enemy_hh[3] = enemy_3[3:0];

    integer e, j;
    reg [7:0] ex, ey;
    reg [3:0] hw, hh;


    always @(posedge clk) begin
        dy = $signed(offset_num);
        impact_detected = 0;
        impact_x = 0;
        impact_y = 0;
        case (projectile_type)
            0: begin // Straight line projectile
                for (i = 0; i < 96; i = i + 1) begin
                    projectile_y[i] = 8'd65;  // Initialize all projectile_y to 65
                end
                for (i = x; i < 96; i = i + 1) begin
                    numerator = offset_num * (i - x0);
                    y_calc = y0 + (numerator / 50);
                    if (y_calc >= 65 || y_calc < 0) begin
                        projectile_y[i] = 8'd65;
                    end
                    else begin
                        projectile_y[i] = y_calc[7:0];
                    end

                    if (!impact_detected && projectile_y[i] <= terrain[i]) begin
                        impact_detected = 1;
                        impact_x = i[7:0];
                        impact_y = projectile_y[i];
                    end
                end
            end

            1: begin // Parabolic projectile
                for (i = 0; i < 96; i = i + 1) begin
                    projectile_y[i] = 8'd65;
                end
                for (i = x; i < 96; i = i + 1) begin
                    dy = dy - g;
                    y_calc = $signed({5'b0, projectile_y[i-1]}) + dy;
                    if (y_calc >= 65 || y_calc < 0) begin
                        projectile_y[i] = 8'd65;
                    end
                    else begin
                        projectile_y[i] = y_calc[7:0];
                    end

                    if (!impact_detected && projectile_y[i] <= terrain[i]) begin
                        impact_detected = 1;
                        impact_x = i[7:0];
                        impact_y = projectile_y[i];
                    end
                end
            end
        endcase

        // Enemy hit detection
        for (e = 0; e < 4; e = e + 1) begin
            ex = enemy_x[e];
            ey = enemy_y[e];
            hw = enemy_hw[e];
            hh = enemy_hh[e];

            for (j = ex - hw; j <= ex + hw; j = j + 1) begin
                if (j >= 0 && j < 96) begin
                    if (!hit_flag &&
                    projectile_y[j] >= ey - hh &&
                    projectile_y[j] <= ey + hh) begin
                        hit_flag = 1;
                        hit_enemy_index = e[1:0];
                        hit_x = j[7:0];
                        hit_y = projectile_y[j];
                    end
                end
            end
        end
    end


endmodule
