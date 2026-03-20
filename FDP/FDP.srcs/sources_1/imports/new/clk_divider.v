`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.03.2026 10:32:47
// Design Name: 
// Module Name: clk_divider
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


module clk_divider(input clk, input [31:0] base_freq, input [31:0] new_freq, output reg clk_out = 0);

    reg [31:0] counter = 0; // Counter to keep track of clock cycles
    reg [31:0] refresh;     // Calculate number of cycles for desired frequency
    always @(base_freq, new_freq) begin
        refresh = (new_freq == 0) ? 0 : (base_freq / (2 * new_freq)) - 1;
    end
    
    always @(posedge clk) begin
        // Increment the counter
        counter <= (counter >= refresh) ? 0 : counter + 1;
        // Toggle the output clock when the counter resets
        clk_out <= (counter == 0) ? ~clk_out : clk_out;
    end

endmodule
