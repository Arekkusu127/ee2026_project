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
    input  [3:0]  entity_id,
    output reg [45:0] entity_data
);

    // Entity types
    localparam TYPE_PLAYER = 2'b00;
    localparam TYPE_MINION = 2'b01;
    localparam TYPE_BOSS   = 2'b10;

    always @(*) begin
        case (entity_id)
            4'd0: // Player
                // TYPE=00, HP=50(x4=200), DEF=5, ATK=25, MP=12, X=10, Y=0, hw=2, hh=1
                entity_data = {TYPE_PLAYER, 6'd50, 6'd5, 6'd25, 6'd12, 7'd10, 6'd0, 4'd2, 3'd1};

            4'd1: // Minion 0
                // TYPE=01, HP=50, DEF=2, ATK=15, MP=0, X=55, Y=0, hw=1, hh=1
                entity_data = {TYPE_MINION, 6'd50, 6'd2, 6'd15, 6'd0, 7'd55, 6'd0, 4'd1, 3'd1};

            4'd2: // Minion 1
                entity_data = {TYPE_MINION, 6'd50, 6'd2, 6'd15, 6'd0, 7'd70, 6'd0, 4'd1, 3'd1};

            4'd3: // Minion 2
                entity_data = {TYPE_MINION, 6'd50, 6'd2, 6'd15, 6'd0, 7'd85, 6'd0, 4'd1, 3'd1};

            4'd4: // Boss
                // TYPE=10, HP=50(x8=400), DEF=8, ATK=30, MP=0, X=80, Y=0, hw=3, hh=2
                entity_data = {TYPE_BOSS, 6'd50, 6'd8, 6'd30, 6'd0, 7'd80, 6'd0, 4'd3, 3'd2};

            default:
                entity_data = {TYPE_MINION, 6'd30, 6'd2, 6'd10, 6'd0, 7'd50, 6'd0, 4'd1, 3'd1};
        endcase
    end

endmodule
