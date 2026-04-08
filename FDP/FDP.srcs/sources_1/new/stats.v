`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qiang Jiayuan
// 
// Create Date: 20.03.2026 21:13:52
// Design Name: 
// Module Name: stats
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module stats(
    input [1:0] entityType,
    output reg [7:0] hp,
    output reg [5:0] def_stat,
    output reg [5:0] atk_stat,
    output reg [3:0] half_width,
    output reg [3:0] half_height
);
    always @(*) begin
        case (entityType)
            2'd0: begin
                hp = 8'd150;
                def_stat = 6'd5;
                atk_stat = 6'd10;
                half_width = 4'd3;
                half_height = 4'd3;
            end
            2'd1: begin
                hp = 8'd100;
                def_stat = 6'd3;
                atk_stat = 6'd8;
                half_width = 4'd2;
                half_height = 4'd2;
            end
            2'd2: begin
                hp = 8'd200;
                def_stat = 6'd8;
                atk_stat = 6'd12;
                half_width = 4'd4;
                half_height = 4'd4;
            end
            default: begin
                hp = 8'd0;
                def_stat = 6'd0;
                atk_stat = 6'd0;
                half_width = 4'd0;
                half_height = 4'd0;
            end
        endcase
    end
endmodule
