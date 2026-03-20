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


module stats(input [1:0] entityType, output reg [7:0] hp);

    always @(*) begin
        case (entityType)
            // Player model
            2'd0: hp = 8'd150;
            // Enemy models
            2'd1: hp = 8'd100;
            2'd2: hp = 8'd200;
            // Default case for undefined entity types
            default: hp = 8'd0;
        endcase
    end

endmodule
