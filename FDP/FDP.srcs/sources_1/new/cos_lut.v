`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2026 18:42:48
// Design Name: 
// Module Name: cos_lut
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


module cos_lut(
    input  [6:0] angle,
    output reg [8:0] cos_val
);
    always @(*) begin
        case (angle)
            7'd0:  cos_val = 9'd256;
            7'd1:  cos_val = 9'd256;
            7'd2:  cos_val = 9'd256;
            7'd3:  cos_val = 9'd255;
            7'd4:  cos_val = 9'd255;
            7'd5:  cos_val = 9'd255;
            7'd6:  cos_val = 9'd254;
            7'd7:  cos_val = 9'd254;
            7'd8:  cos_val = 9'd253;
            7'd9:  cos_val = 9'd253;
            7'd10: cos_val = 9'd252;
            7'd11: cos_val = 9'd251;
            7'd12: cos_val = 9'd250;
            7'd13: cos_val = 9'd249;
            7'd14: cos_val = 9'd248;
            7'd15: cos_val = 9'd247;
            7'd16: cos_val = 9'd246;
            7'd17: cos_val = 9'd244;
            7'd18: cos_val = 9'd243;
            7'd19: cos_val = 9'd242;
            7'd20: cos_val = 9'd240;
            7'd21: cos_val = 9'd238;
            7'd22: cos_val = 9'd237;
            7'd23: cos_val = 9'd235;
            7'd24: cos_val = 9'd233;
            7'd25: cos_val = 9'd231;
            7'd26: cos_val = 9'd229;
            7'd27: cos_val = 9'd227;
            7'd28: cos_val = 9'd225;
            7'd29: cos_val = 9'd223;
            7'd30: cos_val = 9'd221;
            7'd31: cos_val = 9'd219;
            7'd32: cos_val = 9'd216;
            7'd33: cos_val = 9'd214;
            7'd34: cos_val = 9'd212;
            7'd35: cos_val = 9'd209;
            7'd36: cos_val = 9'd207;
            7'd37: cos_val = 9'd204;
            7'd38: cos_val = 9'd201;
            7'd39: cos_val = 9'd199;
            7'd40: cos_val = 9'd196;
            7'd41: cos_val = 9'd193;
            7'd42: cos_val = 9'd190;
            7'd43: cos_val = 9'd187;
            7'd44: cos_val = 9'd184;
            7'd45: cos_val = 9'd181;
            7'd46: cos_val = 9'd178;
            7'd47: cos_val = 9'd174;
            7'd48: cos_val = 9'd171;
            7'd49: cos_val = 9'd168;
            7'd50: cos_val = 9'd164;
            7'd51: cos_val = 9'd161;
            7'd52: cos_val = 9'd158;
            7'd53: cos_val = 9'd154;
            7'd54: cos_val = 9'd150;
            7'd55: cos_val = 9'd147;
            7'd56: cos_val = 9'd143;
            7'd57: cos_val = 9'd139;
            7'd58: cos_val = 9'd135;
            7'd59: cos_val = 9'd131;
            7'd60: cos_val = 9'd128;
            7'd61: cos_val = 9'd124;
            7'd62: cos_val = 9'd120;
            7'd63: cos_val = 9'd116;
            7'd64: cos_val = 9'd112;
            7'd65: cos_val = 9'd108;
            7'd66: cos_val = 9'd104;
            7'd67: cos_val = 9'd100;
            7'd68: cos_val = 9'd95;
            7'd69: cos_val = 9'd91;
            7'd70: cos_val = 9'd87;
            7'd71: cos_val = 9'd83;
            7'd72: cos_val = 9'd79;
            7'd73: cos_val = 9'd74;
            7'd74: cos_val = 9'd70;
            7'd75: cos_val = 9'd66;
            7'd76: cos_val = 9'd62;
            7'd77: cos_val = 9'd57;
            7'd78: cos_val = 9'd53;
            7'd79: cos_val = 9'd49;
            7'd80: cos_val = 9'd44;
            7'd81: cos_val = 9'd40;
            7'd82: cos_val = 9'd36;
            7'd83: cos_val = 9'd31;
            7'd84: cos_val = 9'd27;
            7'd85: cos_val = 9'd22;
            7'd86: cos_val = 9'd18;
            7'd87: cos_val = 9'd13;
            7'd88: cos_val = 9'd9;
            7'd89: cos_val = 9'd4;
            7'd90: cos_val = 9'd0;
            default: cos_val = 9'd256;
        endcase
    end
endmodule
