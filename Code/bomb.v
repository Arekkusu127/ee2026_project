module bomb(
    input        CLOCK,
    input        rst,
    input        frame_begin,
    input        trigger,       // 1-cycle pulse
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

    reg        active;
    reg        frame_sel;      // 0 = rom0, 1 = rom1
    reg [5:0]  frame_cnt;      // enough for 0..63

    always @(posedge CLOCK or posedge rst) begin
        if (rst) begin
            active    <= 1'b0;
            frame_sel <= 1'b0;
            frame_cnt <= 6'd0;
        end
        else if (frame_begin) begin
            if (trigger) begin
                active    <= 1'b1;
                frame_sel <= 1'b0;
                frame_cnt <= 6'd0;
            end
            else if (active) begin
                frame_cnt <= frame_cnt + 1'b1;

                // first half: bomb1, second half: bomb2
                if (frame_cnt >= 6'd15)
                    frame_sel <= 1'b1;

                // total about 30 frames ~= 0.5s at 60fps
                if (frame_cnt >= 6'd29) begin
                    active    <= 1'b0;
                    frame_sel <= 1'b0;
                    frame_cnt <= 6'd0;
                end
            end
        end
    end

    wire [15:0] bomb_pixel = frame_sel ? rom1[addr] : rom0[addr];

    assign pixel   = bomb_pixel;
    assign visible = active && (bomb_pixel != 16'hffff);

endmodule