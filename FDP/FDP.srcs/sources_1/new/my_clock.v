module my_clock(
    input CLOCK,
    input [31:0] my_m_value,
    output reg my_clk = 0
    );
    reg [31:0] count = 0;
    always @(posedge CLOCK) begin
        count <= (count == my_m_value) ? 0 : count + 1;
        my_clk <= (count == 0) ? ~my_clk : my_clk;
    end
endmodule

module my_counter(
    input clk,
    input [31:0] my_m_value,
    output reg [31:0] count = 1
    );
    always @(posedge clk) begin
        count <= (count == (my_m_value - 1)) ? 0 : count + 1;
    end
endmodule
