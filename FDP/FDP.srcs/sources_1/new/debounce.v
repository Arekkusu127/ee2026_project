`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Qiang Jiayuan
// 
// Create Date: 08.04.2026 18:33:59
// Design Name: 
// Module Name: debounce
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


module debounce(
    input  clk,
    input  rst,
    input  btn_in,
    output reg btn_out
);
    reg [19:0] cnt = 0;
    reg        state = 0;
    reg        btn_sync0, btn_sync1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_sync0 <= 0;
            btn_sync1 <= 0;
        end else begin
            btn_sync0 <= btn_in;
            btn_sync1 <= btn_sync0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt     <= 0;
            state   <= 0;
            btn_out <= 0;
        end else begin
            btn_out <= 0;
            if (state == 0) begin
                if (btn_sync1) begin
                    cnt <= cnt + 1;
                    if (cnt == 20'd999_999) begin
                        state   <= 1;
                        btn_out <= 1;
                        cnt     <= 0;
                    end
                end else
                    cnt <= 0;
            end else begin
                if (!btn_sync1) begin
                    cnt <= cnt + 1;
                    if (cnt == 20'd999_999) begin
                        state <= 0;
                        cnt   <= 0;
                    end
                end else
                    cnt <= 0;
            end
        end
    end
endmodule

