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

`timescale 1ns / 1ps

module stats(
    input  [3:0]  entity_id,
    output reg [45:0] entity_data,
    output reg [8:0]  real_hp
);

    localparam TYPE_PLAYER = 2'b00;
    localparam TYPE_MINION = 2'b01;
    localparam TYPE_BOSS   = 2'b10;

    always @(*) begin
        case (entity_id)
            4'd0: begin // Player
                entity_data = {TYPE_PLAYER, 6'd50, 6'd5, 6'd25, 6'd12, 7'd20, 6'd0, 4'd3, 3'd3};
                real_hp = 9'd200;
            end
            4'd1: begin // Slime 0
                entity_data = {TYPE_MINION, 6'd50, 6'd0, 6'd0, 6'd0, 7'd89, 6'd49, 4'd7, 3'd4};
                real_hp = 9'd50;
            end
            4'd2: begin // Slime 1
                entity_data = {TYPE_MINION, 6'd50, 6'd0, 6'd0, 6'd0, 7'd103, 6'd49, 4'd7, 3'd4};
                real_hp = 9'd50;
            end
            4'd3: begin // Boss
                entity_data = {TYPE_BOSS, 6'd63, 6'd30, 6'd40, 6'd0, 7'd75, 6'd32, 4'd5, 3'd4};
                real_hp = 9'd400;
            end
            default: begin
                entity_data = 46'd0;
                real_hp = 9'd0;
            end
        endcase
    end

endmodule

