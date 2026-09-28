`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 27.09.2026
// Design Name: 
// Module Name: rhythm_checker
// Project Name: Beat Master
// Target Devices: Zybo Z7-10
// Tool Versions: Vivado 2026.1
// Description: Compares player's tap timing against the generated sequence,
//              applying a +/- tolerance window to the expected interval.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rhythm_checker #(
    parameter TIME_8TH_MS   = 250,
    parameter TIME_4TH_MS   = 500,
    parameter TIME_HALF_MS  = 1000,
    parameter TIME_WHOLE_MS = 2000
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,          // High when FSM is in INPUT or CHECK state
    
    // From tap_detector
    input  wire [15:0] tap_interval_ms,
    input  wire        tap_valid,       // 1-cycle pulse when a new interval is ready
    
    // From beat_generator
    input  wire [23:0] beat_sequence,
    input  wire [3:0]  beat_count,
    
    // Outputs to FSM
    output reg         check_done,      // Pulses high when sequence finishes or player fails
    output reg         win_flag         // 1 if successful, 0 if failed (valid when check_done is 1)
);
    reg [3:0] current_index;
    
    // Extract the 2-bit code for the note we are currently expecting the user to match
    wire [1:0] current_beat_code = beat_sequence[current_index*2 +: 2];
    
    // Decode expected duration
    reg [15:0] expected_ms;
    
    always @(*) begin
        case(current_beat_code)
            2'b00: expected_ms = TIME_8TH_MS;
            2'b01: expected_ms = TIME_4TH_MS;
            2'b10: expected_ms = TIME_HALF_MS;
            2'b11: expected_ms = TIME_WHOLE_MS;
            default: expected_ms = TIME_4TH_MS;
        endcase
    end

    // Proportional Tolerance: 25% of expected duration (bit shift right by 2)
    wire [15:0] tolerance = expected_ms >> 2;

    always @(posedge clk) begin
        if (reset) begin
            current_index <= 4'd0;
            check_done    <= 1'b0;
            win_flag      <= 1'b0;
        end
        else if (enable) begin
            // Wait for a valid tap, and only evaluate if we haven't already finished
            if (tap_valid && !check_done) begin
                // Check if the tap interval falls within the [Expected +/- 25%] window
                if ((tap_interval_ms >= (expected_ms - tolerance)) && 
                    (tap_interval_ms <= (expected_ms + tolerance))) begin
                    
                    // The tap was CORRECT
                    // Check if we have completed (beat_count - 1) intervals
                    if (current_index + 4'd2 == beat_count) begin
                        // Reached the end of the sequence successfully!
                        check_done <= 1'b1;
                        win_flag   <= 1'b1;
                    end 
                    else begin
                        // Move to the next note in the sequence
                        current_index <= current_index + 1'b1;
                    end
                end
                else begin
                    // The tap was INCORRECT (outside tolerance)
                    check_done <= 1'b1;
                    win_flag   <= 1'b0;
                end
            end
        end
        else begin
            // Reset state when FSM drops enable
            current_index <= 4'd0;
            check_done    <= 1'b0;
            win_flag      <= 1'b0;
        end
    end
endmodule