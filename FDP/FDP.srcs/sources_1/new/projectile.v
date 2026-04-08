`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qiang Jiayuan
// 
// Create Date: 28.03.2026 01:43:14
// Design Name: 
// Module Name: projectile
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Weapon lookup table. 15 weapons (0-14).
//              weapon_id from game_state (sw[14:1] priority mux).
//              Weapon 0 = free basic shot (default when no switch active).
//              sw[15] reserved for reset, not used here.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Reduced to 15 weapons (0-14), sw[15] reserved
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module projectile(
    input  [3:0]  skill_id,       // 0-15 from switches
    input  [4:0]  energy,
    input  [5:0]  entity_atk,
    output reg [7:0] base_damage,
    output reg [3:0] energy_cost,
    output reg [1:0] trajectory_type,
    output reg [3:0] blast_radius,
    output reg       can_fire
);

    localparam ARC      = 2'd0;
    localparam STRAIGHT = 2'd1;
    localparam BOUNCE   = 2'd2;
    localparam SPECIAL  = 2'd3;

    reg [7:0] raw_damage;

    always @(*) begin
        // Energy cost = skill_id (0 = free basic, 1 = 1 energy, ..., 15 = 15 energy)
        energy_cost = skill_id;

        case (skill_id)
            4'd0:  begin raw_damage = 8'd15;  trajectory_type = ARC;      blast_radius = 4'd2; end  // Basic
            4'd1:  begin raw_damage = 8'd18;  trajectory_type = ARC;      blast_radius = 4'd2; end
            4'd2:  begin raw_damage = 8'd22;  trajectory_type = ARC;      blast_radius = 4'd3; end
            4'd3:  begin raw_damage = 8'd25;  trajectory_type = ARC;      blast_radius = 4'd3; end
            4'd4:  begin raw_damage = 8'd28;  trajectory_type = STRAIGHT; blast_radius = 4'd2; end
            4'd5:  begin raw_damage = 8'd30;  trajectory_type = ARC;      blast_radius = 4'd4; end
            4'd6:  begin raw_damage = 8'd33;  trajectory_type = BOUNCE;   blast_radius = 4'd3; end
            4'd7:  begin raw_damage = 8'd36;  trajectory_type = ARC;      blast_radius = 4'd4; end
            4'd8:  begin raw_damage = 8'd39;  trajectory_type = ARC;      blast_radius = 4'd5; end
            4'd9:  begin raw_damage = 8'd42;  trajectory_type = STRAIGHT; blast_radius = 4'd4; end
            4'd10: begin raw_damage = 8'd45;  trajectory_type = ARC;      blast_radius = 4'd5; end
            4'd11: begin raw_damage = 8'd48;  trajectory_type = ARC;      blast_radius = 4'd6; end
            4'd12: begin raw_damage = 8'd51;  trajectory_type = ARC;      blast_radius = 4'd6; end
            4'd13: begin raw_damage = 8'd54;  trajectory_type = STRAIGHT; blast_radius = 4'd5; end
            4'd14: begin raw_damage = 8'd57;  trajectory_type = ARC;      blast_radius = 4'd7; end
            4'd15: begin raw_damage = 8'd63;  trajectory_type = ARC;      blast_radius = 4'd8; end  // Nuke
            default: begin raw_damage = 8'd15; trajectory_type = ARC;     blast_radius = 4'd2; end
        endcase

        base_damage = raw_damage + {2'd0, entity_atk};
        can_fire = (energy >= {1'b0, energy_cost});
    end

endmodule

