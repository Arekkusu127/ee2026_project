module girl(
    input frame_begin,
    input game_started,
    input [4:0] x_pos,
    input [4:0] y_pos,
    output  [15:0] pixel,
    output visible
    
);
    reg [15:0] rom [0:899];  // 900 pixels, each 16 bits
    initial begin
        $readmemb("D:/FDP/FDP.srcs/sources_1/new/girl.bin", rom);
    end
    wire [9:0] addr = y_pos * 30 + x_pos; // 30 pixels per row
    assign pixel = rom[addr];
    wire [4:0] r = pixel[15:11];
    wire [5:0] g = pixel[10:5];
    wire [4:0] b = pixel[4:0];
    assign visible = !( (r >= 28) && (g >= 45) && (g <= 55) && (b >= 28) );
    
endmodule