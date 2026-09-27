`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 24.09.2026 21:27:53
// Design Name: 
// Module Name: button_debounce
// Project Name: Beat Master
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


module button_debounce#(
    parameter integer DEBOUNCE_COUNT = 1_250_000
)(
    input  wire clk,
    input  wire reset,
    input  wire button_in,
    output reg  button_out
);
    reg button_sync_0;
    
    // prevent metastability
    reg button_sync_1;
    reg button_state;

    reg [31:0] counter;
    
    always @(posedge clk) begin
        if (reset) begin
            button_sync_0 <= 1'b0;
            button_sync_1 <= 1'b0;
            button_state  <= 1'b0;
            button_out    <= 1'b0;
            counter       <= 32'd0;
        end
        else begin
            button_sync_0 <= button_in;
            button_sync_1 <= button_sync_0;
            
            if (button_sync_1 != button_state) begin
                if (counter < DEBOUNCE_COUNT) begin
                    counter <= counter + 1'b1;
                end
                else begin
                    button_state <= button_sync_1;
                    button_out   <= button_sync_1;
                    counter      <= 32'd0;
                end
            end
            else begin
                counter <= 32'd0;
            end
        end
    end
endmodule
