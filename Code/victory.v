module victory(
    input  [6:0] hcount,
    input  [5:0] vcount,
    output [15:0] pixel
);
    reg [15:0] rom [0:6143];  // 6144 pixels, each 16 bits
    initial begin
    `ifdef SYNTHESIS
        $readmemb("../../FDP.srcs/resources_1/victory.bin", rom);
    `else
        $readmemb("../../../../FDP.srcs/resources_1/victory.bin", rom);
    `endif
    end
    wire [12:0] addr = ({vcount, 6'd0} + {vcount, 5'd0}) + {6'd0, hcount};
    assign pixel = rom[addr];
endmodule