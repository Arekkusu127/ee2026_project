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
// Description: Weapon selection, energy management, and projectile sequencer.
//              17 weapons (cost 0-16), selected via 16 switches
//              or default to basic (cost 0) when no switch active.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
Weapon selection, energy management, and projectile parameters.
Uses entity ATK field to scale damage.
*/

module projectile(
    input  [3:0]  skill_id,
    input  [4:0]  energy,
    input  [5:0]  entity_atk,    // ATK from shooter entity [31:26]
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
        raw_damage      = 8'd20;
        energy_cost     = 4'd2;
        trajectory_type = ARC;
        blast_radius    = 4'd2;

        casez (skill_id)
            4'b0000: begin raw_damage = 8'd20;  energy_cost = 4'd2;  trajectory_type = ARC;      blast_radius = 4'd2; end
            4'b0001: begin raw_damage = 8'd12;  energy_cost = 4'd3;  trajectory_type = ARC;      blast_radius = 4'd4; end
            4'b0010: begin raw_damage = 8'd25;  energy_cost = 4'd4;  trajectory_type = ARC;      blast_radius = 4'd3; end
            4'b0011: begin raw_damage = 8'd35;  energy_cost = 4'd5;  trajectory_type = ARC;      blast_radius = 4'd5; end
            4'b0100: begin raw_damage = 8'd40;  energy_cost = 4'd6;  trajectory_type = STRAIGHT; blast_radius = 4'd1; end
            4'b0101: begin raw_damage = 8'd18;  energy_cost = 4'd3;  trajectory_type = BOUNCE;   blast_radius = 4'd2; end
            4'b0110: begin raw_damage = 8'd10;  energy_cost = 4'd1;  trajectory_type = ARC;      blast_radius = 4'd1; end
            4'b0111: begin raw_damage = 8'd50;  energy_cost = 4'd8;  trajectory_type = ARC;      blast_radius = 4'd3; end
            4'b1000: begin raw_damage = 8'd0;   energy_cost = 4'd4;  trajectory_type = SPECIAL;  blast_radius = 4'd0; end
            4'b1001: begin raw_damage = 8'd0;   energy_cost = 4'd5;  trajectory_type = SPECIAL;  blast_radius = 4'd0; end
            4'b1010: begin raw_damage = 8'd30;  energy_cost = 4'd5;  trajectory_type = STRAIGHT; blast_radius = 4'd1; end
            4'b1011: begin raw_damage = 8'd15;  energy_cost = 4'd6;  trajectory_type = ARC;      blast_radius = 4'd6; end
            4'b1100: begin raw_damage = 8'd45;  energy_cost = 4'd7;  trajectory_type = ARC;      blast_radius = 4'd4; end
            4'b1101: begin raw_damage = 8'd22;  energy_cost = 4'd4;  trajectory_type = BOUNCE;   blast_radius = 4'd2; end
            4'b1110: begin raw_damage = 8'd55;  energy_cost = 4'd10; trajectory_type = STRAIGHT; blast_radius = 4'd1; end
            4'b1111: begin raw_damage = 8'd80;  energy_cost = 4'd15; trajectory_type = ARC;      blast_radius = 4'd8; end
        endcase

        // Scale base_damage by entity ATK: damage = raw + (entity_atk / 4)
        base_damage = raw_damage + {2'd0, entity_atk};

        can_fire = (energy >= {1'b0, energy_cost});
    end

endmodule
