module bomb(
    input        CLOCK,
    input        rst,
    input        frame_begin,
    input        explosion_pending,         // 1-cycle pulse when a new explosion starts
    input  [2:0] x_pos,
    input  [2:0] y_pos,
    output [15:0] pixel,
    output       visible
);
    reg [15:0] rom0 [0:35];
    reg [15:0] rom1 [0:35];

    initial begin
    `ifdef SYNTHESIS
        $readmemb("../../FDP.srcs/resources_1/bomb1.bin", rom0);
        $readmemb("../../FDP.srcs/resources_1/bomb2.bin", rom1);
    `else
        $readmemb("../../../../FDP.srcs/resources_1/bomb1.bin", rom0);
        $readmemb("../../../../FDP.srcs/resources_1/bomb2.bin", rom1);
    `endif
    end

    wire [5:0] addr = y_pos * 6 + {3'd0, x_pos};

    // 0 = hidden, 1 = show rom0, 2 = show rom1
    reg [1:0] anim_state;
    reg [1:0] hold_cnt;

    always @(posedge CLOCK or posedge rst) begin
        if (rst) begin
            anim_state <= 2'd0;
            hold_cnt   <= 2'd0;
        end
        else if (frame_begin) begin
            case (anim_state)
                2'd0: begin
                    if (explosion_pending) begin
                        anim_state <= 2'd1; // show bomb1
                        hold_cnt   <= 2'd0;
                    end
                end

                2'd1: begin
                    // hold rom0 briefly, then switch to rom1
                    if (hold_cnt == 2'd1) begin
                        anim_state <= 2'd2;
                        hold_cnt   <= 2'd0;
                    end else begin
                        hold_cnt <= hold_cnt + 1'b1;
                    end
                end

                2'd2: begin
                    // hold rom1 briefly, then disappear
                    if (hold_cnt == 2'd1) begin
                        anim_state <= 2'd0;
                        hold_cnt   <= 2'd0;
                    end else begin
                        hold_cnt <= hold_cnt + 1'b1;
                    end
                end

                default: begin
                    anim_state <= 2'd0;
                    hold_cnt   <= 2'd0;
                end
            endcase
        end
    end

    wire [15:0] bomb_pixel = (anim_state == 2'd2) ? rom1[addr] : rom0[addr];

    assign pixel   = bomb_pixel;
    assign visible = (anim_state != 2'd0) && (bomb_pixel != 16'hffff);
endmodule