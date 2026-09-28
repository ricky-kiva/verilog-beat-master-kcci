`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 25.09.2026 10:11:16
// Design Name: 
// Module Name: top
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


module top (
    input  wire       clk,     // 125 MHz system clock
    input  wire [2:0] btn,     // btn[0]=Reset, btn[1]=Start, btn[2]=Tap
    input  wire [2:0] sw,      // sw[0]=sw1(4 notes), sw[1]=sw2(8 notes), sw[2]=sw3(12 notes)
    output wire [2:0] led      // led[0]=Rhythm/Tap feedback, led[1]=Win streak
);
    // ==========================================
    // Internal Wiring
    // ==========================================
    wire reset = btn[0];
    
    wire btn1_debounced;
    wire btn2_debounced;

    wire [23:0] beat_sequence; 
    wire [3:0]  beat_count;

    wire gen_start;
    wire gen_done;
    
    wire play_start;
    wire play_done;
    
    wire input_enable;
    
    wire [15:0] tap_interval_ms;
    wire tap_valid;
    wire tap_pulse;
    
    wire check_done;
    wire win_flag;
    
    wire player_led_out;
    wire win_led_out;

    // ==========================================
    // Output Logic
    // ==========================================
    // led[0] flashes when the game plays the rhythm OR when the user taps
    assign led[0] = player_led_out | tap_pulse;
    assign led[1] = win_led_out;
    
    // led[2] turns on when beats are fully generated and played, waiting for user taps
    assign led[2] = input_enable;

    // ==========================================
    // Module Instantiations
    // ==========================================

    // Debouncer for Start Button (BTN1)
    button_debounce btn1_inst (
        .clk(clk),
        .reset(reset),
        .button_in(btn[1]),
        .button_out(btn1_debounced)
    );

    // Debouncer for Tap Button (BTN2)
    button_debounce btn2_inst (
        .clk(clk),
        .reset(reset),
        .button_in(btn[2]),
        .button_out(btn2_debounced)
    );

    // Generates the random sequence of beat lengths
    beat_generator gen_inst (
        .clk(clk),
        .reset(reset),
        .start(gen_start),
        .sw1(sw[0]),
        .sw2(sw[1]),
        .sw3(sw[2]),
        .beat_sequence(beat_sequence),
        .beat_count(beat_count),
        .done(gen_done)
    );

    // Plays the generated sequence out to LED0
    beat_player player_inst (
        .clk(clk),
        .reset(reset),
        .start(play_start),
        .beat_sequence(beat_sequence), 
        .beat_count(beat_count),
        .led_out(player_led_out),
        .done(play_done)
    );

    // Measures ms intervals between BTN2 taps
    tap_detector tap_inst (
        .clk(clk),
        .reset(reset),
        .enable(input_enable),
        .tap_in(btn2_debounced),
        .tap_pulse(tap_pulse),
        .tap_interval_ms(tap_interval_ms),
        .tap_valid(tap_valid),
        .first_tap_detected() // Unused at top level
    );

    // Evaluates tap accuracy against expected rhythm
    rhythm_checker check_inst (
        .clk(clk),
        .reset(reset),
        .enable(input_enable),
        .tap_interval_ms(tap_interval_ms),
        .tap_valid(tap_valid),
        .beat_sequence(beat_sequence), 
        .beat_count(beat_count),
        .check_done(check_done),
        .win_flag(win_flag)
    );

    // Main Game Controller
    game_fsm fsm_inst (
        .clk(clk),
        .reset(reset),
        .btn1_in(btn1_debounced),
        .gen_done(gen_done),
        .play_done(play_done),
        .check_done(check_done),
        .win_flag(win_flag),
        .gen_start(gen_start),
        .play_start(play_start),
        .input_enable(input_enable),
        .led2_out(win_led_out)
    );
endmodule