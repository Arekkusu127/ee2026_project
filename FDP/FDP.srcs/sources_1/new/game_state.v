`timescale 1ns / 1ps

module game_state(
    input         clk,
    input         tick,
    input         btnU, btnD, btnL, btnR, btnC,
    input  [3:0]  sw,
    input  [575:0] terrain_flat,
    input         map_done,
    input         hit_flag,
    input  [7:0]  damage,
    input         proj_active,
    output reg [2:0]  phase,
    output reg        turn,
    output reg [7:0]  angle,
    output reg [3:0]  power,
    output reg [4:0]  energy,
    output [15:0]     hp_flat,
    output reg        fire_trigger,
    output reg [3:0]  skill_id,
    output reg        game_over,
    output reg        winner
);

    // Phases
    localparam INIT      = 3'd0;
    localparam AIM       = 3'd1;
    localparam FIRE      = 3'd2;
    localparam ANIMATE   = 3'd3;
    localparam RESOLVE   = 3'd4;
    localparam NEXT_TURN = 3'd5;
    localparam GAMEOVER  = 3'd6;

    reg [7:0] hp [0:1];
    assign hp_flat[7:0]  = hp[0];
    assign hp_flat[15:8] = hp[1];

    // Button edge detection
    reg btnC_prev, btnU_prev, btnD_prev, btnL_prev, btnR_prev;
    wire btnC_edge = btnC & ~btnC_prev;
    wire btnU_edge = btnU & ~btnU_prev;
    wire btnD_edge = btnD & ~btnD_prev;
    wire btnL_edge = btnL & ~btnL_prev;
    wire btnR_edge = btnR & ~btnR_prev;

    always @(posedge clk) begin
        btnC_prev <= btnC;
        btnU_prev <= btnU;
        btnD_prev <= btnD;
        btnL_prev <= btnL;
        btnR_prev <= btnR;
    end

    // Debounced tick-based state machine
    always @(posedge clk) begin
        fire_trigger <= 0;

        case (phase)
            INIT: begin
                if (map_done) begin
                    hp[0]     <= 8'd150;
                    hp[1]     <= 8'd150;
                    turn      <= 0;
                    angle     <= 8'd45;
                    power     <= 4'd5;
                    energy    <= 5'd4;
                    skill_id  <= 4'd0;
                    game_over <= 0;
                    winner    <= 0;
                    phase     <= AIM;
                end
            end

            AIM: begin
                if (tick) begin
                    if (btnU_edge && angle < 8'd90)
                        angle <= angle + 1;
                    if (btnD_edge && angle > 0)
                        angle <= angle - 1;
                    if (btnR_edge && power < 4'd10)
                        power <= power + 1;
                    if (btnL_edge && power > 4'd1)
                        power <= power - 1;

                    skill_id <= sw;

                    if (btnC_edge) begin
                        fire_trigger <= 1;
                        phase <= FIRE;
                    end
                end
            end

            FIRE: begin
                // One-cycle fire pulse already sent
                phase <= ANIMATE;
            end

            ANIMATE: begin
                if (!proj_active) begin
                    phase <= RESOLVE;
                end
            end

            RESOLVE: begin
                if (hit_flag) begin
                    if (turn == 0) begin
                        // Player 0 attacked player 1
                        if (hp[1] <= damage)
                            hp[1] <= 0;
                        else
                            hp[1] <= hp[1] - damage;
                    end else begin
                        if (hp[0] <= damage)
                            hp[0] <= 0;
                        else
                            hp[0] <= hp[0] - damage;
                    end
                end
                phase <= NEXT_TURN;
            end

            NEXT_TURN: begin
                if (hp[0] == 0) begin
                    game_over <= 1;
                    winner    <= 1;  // player 1 wins
                    phase     <= GAMEOVER;
                end else if (hp[1] == 0) begin
                    game_over <= 1;
                    winner    <= 0;  // player 0 wins
                    phase     <= GAMEOVER;
                end else begin
                    turn  <= ~turn;
                    angle <= 8'd45;
                    power <= 4'd5;
                    if (energy < 5'd16)
                        energy <= energy + 2;
                    phase <= AIM;
                end
            end

            GAMEOVER: begin
                // Stay here until reset
            end
        endcase
    end

endmodule
