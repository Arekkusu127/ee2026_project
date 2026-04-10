module bomb2(
    input frame_begin,
    input [2:0] x_pos,
    input [2:0] y_pos,
    output [15:0] pixel,
    output visible
);
    reg [15:0] rom [0:35]; // 36 pixels, each 16 bits
    initial begin
        `ifdef SYNTHESIS
            $readmemb("../../FDP.srcs/resources_1/bomb2.bin", rom);
        `else
            $readmemb("../../../../FDP.srcs/resources_1/bomb2.bin", rom);
        `endif
    end

    wire [5:0] addr = y_pos * 6 + {3'd0, x_pos};
    assign pixel = rom[addr];
    assign visible = (pixel != 16'hffff);
endmodule