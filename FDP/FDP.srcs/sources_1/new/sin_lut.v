`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2026 18:42:48
// Design Name: 
// Module Name: sin_lut
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


module sin_lut(
    input  [6:0] angle,
    output reg [8:0] sin_val
);
    always @(*) begin
        case (angle)
            7'd0:  sin_val = 9'd0;
            7'd1:  sin_val = 9'd4;
            7'd2:  sin_val = 9'd9;
            7'd3:  sin_val = 9'd13;
            7'd4:  sin_val = 9'd18;
            7'd5:  sin_val = 9'd22;
            7'd6:  sin_val = 9'd27;
            7'd7:  sin_val = 9'd31;
            7'd8:  sin_val = 9'd36;
            7'd9:  sin_val = 9'd40;
            7'd10: sin_val = 9'd44;
            7'd11: sin_val = 9'd49;
            7'd12: sin_val = 9'd53;
            7'd13: sin_val = 9'd57;
            7'd14: sin_val = 9'd62;
            7'd15: sin_val = 9'd66;
            7'd16: sin_val = 9'd70;
            7'd17: sin_val = 9'd74;
            7'd18: sin_val = 9'd79;
            7'd19: sin_val = 9'd83;
            7'd20: sin_val = 9'd87;
            7'd21: sin_val = 9'd91;
            7'd22: sin_val = 9'd95;
            7'd23: sin_val = 9'd100;
            7'd24: sin_val = 9'd104;
            7'd25: sin_val = 9'd108;
            7'd26: sin_val = 9'd112;
            7'd27: sin_val = 9'd116;
            7'd28: sin_val = 9'd120;
            7'd29: sin_val = 9'd124;
            7'd30: sin_val = 9'd128;
            7'd31: sin_val = 9'd131;
            7'd32: sin_val = 9'd135;
            7'd33: sin_val = 9'd139;
            7'd34: sin_val = 9'd143;
            7'd35: sin_val = 9'd147;
            7'd36: sin_val = 9'd150;
            7'd37: sin_val = 9'd154;
            7'd38: sin_val = 9'd158;
            7'd39: sin_val = 9'd161;
            7'd40: sin_val = 9'd164;
            7'd41: sin_val = 9'd168;
            7'd42: sin_val = 9'd171;
            7'd43: sin_val = 9'd174;
            7'd44: sin_val = 9'd178;
            7'd45: sin_val = 9'd181;
            7'd46: sin_val = 9'd184;
            7'd47: sin_val = 9'd187;
            7'd48: sin_val = 9'd190;
            7'd49: sin_val = 9'd193;
            7'd50: sin_val = 9'd196;
            7'd51: sin_val = 9'd199;
            7'd52: sin_val = 9'd201;
            7'd53: sin_val = 9'd204;
            7'd54: sin_val = 9'd207;
            7'd55: sin_val = 9'd209;
            7'd56: sin_val = 9'd212;
            7'd57: sin_val = 9'd214;
            7'd58: sin_val = 9'd216;
            7'd59: sin_val = 9'd219;
            7'd60: sin_val = 9'd221;
            7'd61: sin_val = 9'd223;
            7'd62: sin_val = 9'd225;
            7'd63: sin_val = 9'd227;
            7'd64: sin_val = 9'd229;
            7'd65: sin_val = 9'd231;
            7'd66: sin_val = 9'd233;
            7'd67: sin_val = 9'd235;
            7'd68: sin_val = 9'd237;
            7'd69: sin_val = 9'd238;
            7'd70: sin_val = 9'd240;
            7'd71: sin_val = 9'd242;
            7'd72: sin_val = 9'd243;
            7'd73: sin_val = 9'd244;
            7'd74: sin_val = 9'd246;
            7'd75: sin_val = 9'd247;
            7'd76: sin_val = 9'd248;
            7'd77: sin_val = 9'd249;
            7'd78: sin_val = 9'd250;
            7'd79: sin_val = 9'd251;
            7'd80: sin_val = 9'd252;
            7'd81: sin_val = 9'd253;
            7'd82: sin_val = 9'd253;
            7'd83: sin_val = 9'd254;
            7'd84: sin_val = 9'd254;
            7'd85: sin_val = 9'd255;
            7'd86: sin_val = 9'd255;
            7'd87: sin_val = 9'd255;
            7'd88: sin_val = 9'd256;
            7'd89: sin_val = 9'd256;
            7'd90: sin_val = 9'd256;
            default: sin_val = 9'd0;
        endcase
    end
endmodule

