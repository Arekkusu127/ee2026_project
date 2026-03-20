`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
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


module stats(input [1:0] entityType, output reg [15:0] stats_concat);
    
    reg [7:0] atk; reg [7:0] hp; 

    always @(*) begin
        case (entityType)
            // Player model
            2'd0: begin atk = 8'd100; hp = 8'd150; end
            // Enemy models
            2'd1: begin atk = 8'd100; hp = 8'd100; end
            2'd2: begin atk = 8'd100; hp = 8'd200; end
            // Default case for undefined entity types
            default: begin atk = 8'd0; hp = 8'd0; end
        endcase

        stats_concat = {atk, hp};
    end

endmodule
