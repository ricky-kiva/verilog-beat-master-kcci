`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 25.09.2026 01:38:57
// Design Name: 
// Module Name: beat_player
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


module beat_player #( 
    // Durations in ms (Assuming 120 BPM -> 1 beat (Quarter) = 500ms)
    parameter TIME_8TH_MS    = 250,
    parameter TIME_4TH_MS    = 500,
    parameter TIME_HALF_MS   = 1000,
    parameter TIME_WHOLE_MS  = 2000,
    parameter FLASH_TIME_MS  = 100,
    parameter CLK_FREQ       = 125_000_000
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [23:0] beat_sequence,
    input  wire [3:0]  beat_count,
    output reg         led_out,
    output reg         done
);
    localparam CYCLES_PER_MS = CLK_FREQ / 1000;
    localparam NOTE_8TH      = TIME_8TH_MS * CYCLES_PER_MS;
    localparam NOTE_4TH      = TIME_4TH_MS * CYCLES_PER_MS;
    localparam NOTE_HALF     = TIME_HALF_MS * CYCLES_PER_MS;
    localparam NOTE_WHOLE    = TIME_WHOLE_MS * CYCLES_PER_MS;
    localparam FLASH_DUR     = FLASH_TIME_MS * CYCLES_PER_MS;

    // State Machine Definitions
    localparam IDLE     = 2'd0;
    localparam PLAY_ON  = 2'd1;
    localparam PLAY_OFF = 2'd2;
    localparam DONE_ST  = 2'd3;

    reg [1:0]  state;
    reg [31:0] timer;
    reg [3:0]  current_beat_idx;

    // Decode the current 2-bit sequence into target duration cycles
    wire [1:0] current_beat_code = beat_sequence[current_beat_idx*2 +: 2];
    reg [31:0] current_target_duration;

    always @(*) begin
        case(current_beat_code)
            2'b00: current_target_duration = NOTE_8TH;
            2'b01: current_target_duration = NOTE_4TH;
            2'b10: current_target_duration = NOTE_HALF;
            2'b11: current_target_duration = NOTE_WHOLE;
            default: current_target_duration = NOTE_4TH;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state            <= IDLE;
            led_out          <= 1'b0;
            done             <= 1'b0;
            timer            <= 32'd0;
            current_beat_idx <= 4'd0;
        end 
        else begin
            case (state)
                IDLE: begin
                    done    <= 1'b0;
                    led_out <= 1'b0;
                    if (start && (beat_count > 0)) begin
                        state            <= PLAY_ON;
                        led_out          <= 1'b1;
                        timer            <= 32'd0;
                        current_beat_idx <= 4'd0;
                    end
                end

                PLAY_ON: begin
                    timer <= timer + 1'b1;
                    
                    // Check if flash duration reached
                    if (timer >= FLASH_DUR - 1) begin
                        led_out <= 1'b0;
                        // Guard in case note duration is shorter than or equal to flash duration
                        if (timer >= current_target_duration - 1) begin
                            if (current_beat_idx + 1 >= beat_count) begin
                                state <= DONE_ST;
                            end else begin
                                current_beat_idx <= current_beat_idx + 1'b1;
                                timer            <= 32'd0;
                                led_out          <= 1'b1;
                                state            <= PLAY_ON;
                            end
                        end else begin
                            state <= PLAY_OFF;
                        end
                    end
                end

                PLAY_OFF: begin
                    led_out <= 1'b0;
                    timer   <= timer + 1'b1;
                    
                    // Wait until the full note duration has passed
                    if (timer >= current_target_duration - 1) begin
                        if (current_beat_idx + 1 >= beat_count) begin
                            state <= DONE_ST;
                        end else begin
                            // Move to the next note in the sequence
                            current_beat_idx <= current_beat_idx + 1'b1;
                            timer            <= 32'd0;
                            led_out          <= 1'b1;
                            state            <= PLAY_ON;
                        end
                    end
                end

                DONE_ST: begin
                    done    <= 1'b1;
                    led_out <= 1'b0;
                    state   <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule