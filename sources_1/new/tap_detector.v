`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 26.09.2026
// Design Name: 
// Module Name: tap_detector
// Project Name: Beat Master
// Target Devices: Zybo Z7-10
// Tool Versions: Vivado 2026.1
// Description: Detects BTN2 taps and measures the interval between them in ms.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tap_detector #(
    parameter CLK_FREQ = 125_000_000
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,             // High when FSM is in INPUT state
    input  wire        tap_in,             // Debounced BTN2 input
    
    output wire        tap_pulse,          // 1-cycle strobe on every tap (for LED/audio feedback)
    output reg  [15:0] tap_interval_ms,    // Measured duration between taps
    output reg         tap_valid,          // 1-cycle strobe when tap_interval_ms is updated
    output reg         first_tap_detected  // Flag indicating the rhythm sequence has started
);
    localparam CYCLES_PER_MS = CLK_FREQ / 1000;
    
    reg [31:0] ms_prescaler;
    reg [15:0] ms_counter;
    
    // Edge detection for debounced tap_in
    reg tap_in_d;
    wire tap_edge = (tap_in && !tap_in_d);

    // Provide single-cycle pulse on every tap edge while enabled
    assign tap_pulse = enable && tap_edge;
    
    always @(posedge clk) begin
        if (reset) begin
            tap_in_d           <= 1'b0;
            ms_prescaler       <= 32'd0;
            ms_counter         <= 16'd0;
            tap_interval_ms    <= 16'd0;
            tap_valid          <= 1'b0;
            first_tap_detected <= 1'b0;
        end
        else begin
            tap_in_d  <= tap_in;
            tap_valid <= 1'b0; // Default pulse low
            
            if (enable) begin
                // Tick millisecond counter once the first tap starts the clock
                if (first_tap_detected) begin
                    if (ms_prescaler >= CYCLES_PER_MS - 1) begin
                        ms_prescaler <= 32'd0;
                        if (ms_counter < 16'hFFFF) begin
                            ms_counter <= ms_counter + 1'b1;
                        end
                    end 
                    else begin
                        ms_prescaler <= ms_prescaler + 1'b1;
                    end
                end
                
                // Process rising edge of button press
                if (tap_edge) begin
                    if (!first_tap_detected) begin
                        // Tap 1: Anchor beat - start counting, no interval yet
                        first_tap_detected <= 1'b1;
                        ms_prescaler       <= 32'd0;
                        ms_counter         <= 16'd0;
                    end
                    else begin
                        // Taps 2..N: Output interval, assert valid strobe, reset timer
                        tap_interval_ms <= ms_counter;
                        tap_valid       <= 1'b1;
                        
                        ms_prescaler    <= 32'd0;
                        ms_counter      <= 16'd0;
                    end
                end
            end
            else begin
                // Reset detector state when not in INPUT mode
                first_tap_detected <= 1'b0;
                ms_prescaler       <= 32'd0;
                ms_counter         <= 16'd0;
                tap_interval_ms    <= 16'd0;
            end
        end
    end

endmodule