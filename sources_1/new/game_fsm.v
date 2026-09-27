`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 27.09.2026
// Design Name: 
// Module Name: game_fsm
// Project Name: Beat Master
// Target Devices: Zybo Z7-10
// Tool Versions: Vivado 2026.1
// Description: Main Finite State Machine controlling the flow of the game.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module game_fsm (
    input  wire clk,
    input  wire reset,
    
    // Inputs from player
    input  wire btn1_in,      // Debounced start button
    
    // Status inputs from sub-modules
    input  wire gen_done,     // From beat_generator
    input  wire play_done,    // From beat_player
    input  wire check_done,   // From rhythm_checker
    input  wire win_flag,     // From rhythm_checker
    
    // Control outputs to sub-modules
    output reg  gen_start,
    output reg  play_start,
    output reg  input_enable,
    
    // External output
    output reg  led2_out      // Win streak indicator
);
    // FSM State Encoding
    localparam S_IDLE     = 3'd0;
    localparam S_GENERATE = 3'd1;
    localparam S_PLAY     = 3'd2;
    localparam S_INPUT    = 3'd3;
    localparam S_RESULT   = 3'd4;
    
    reg [2:0] state;
    
    // Edge detection for the Start Button to prevent multi-triggering
    reg btn1_d;
    wire btn1_edge = (btn1_in && !btn1_d);

    always @(posedge clk) begin
        if (reset) begin
            state        <= S_IDLE;
            btn1_d       <= 1'b0;
            gen_start    <= 1'b0;
            play_start   <= 1'b0;
            input_enable <= 1'b0;
            led2_out     <= 1'b0;
        end 
        else begin
            // Update button history for edge detection
            btn1_d <= btn1_in;
            
            // Default output states (ensures gen_start and play_start are 1-cycle pulses)
            gen_start  <= 1'b0;
            play_start <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    if (btn1_edge) begin
                        gen_start <= 1'b1;
                        state     <= S_GENERATE;
                    end
                end
                
                S_GENERATE: begin
                    if (gen_done) begin
                        play_start <= 1'b1;
                        state      <= S_PLAY;
                    end
                end
                
                S_PLAY: begin
                    if (play_done) begin
                        input_enable <= 1'b1;
                        state        <= S_INPUT;
                    end
                end
                
                S_INPUT: begin
                    if (check_done) begin
                        input_enable <= 1'b0;
                        led2_out     <= win_flag; // Update LED status on game finish
                        state        <= S_RESULT;
                    end
                end
                
                S_RESULT: begin
                    // Wait for the user to start a new game
                    // led2_out not cleared, preserving win streaks
                    if (btn1_edge) begin
                        gen_start <= 1'b1;
                        state     <= S_GENERATE;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
