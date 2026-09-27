`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.09.2026 12:58:18
// Design Name: 
// Module Name: tb_game_fsm
// Project Name: Beat Master
// Target Devices: Zybo Z7-10
// Tool Versions: 2026.1
// Description: Self-checking testbench for game_fsm state transitions.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_game_fsm();
    reg clk;
    reg reset;
    reg btn1_in;
    reg gen_done;
    reg play_done;
    reg check_done;
    reg win_flag;
    
    wire gen_start;
    wire play_start;
    wire input_enable;
    wire led2_out;
    
    integer error_count;

    game_fsm uut (
        .clk(clk),
        .reset(reset),
        .btn1_in(btn1_in),
        .gen_done(gen_done),
        .play_done(play_done),
        .check_done(check_done),
        .win_flag(win_flag),
        .gen_start(gen_start),
        .play_start(play_start),
        .input_enable(input_enable),
        .led2_out(led2_out)
    );

    // 100 MHz clock -> 10ns period
    always #5 clk = ~clk;

    initial begin
        clk        = 0;
        reset      = 1;
        btn1_in    = 0;
        gen_done   = 0;
        play_done  = 0;
        check_done = 0;
        win_flag   = 0;
        error_count = 0;

        #100;
        reset = 0;
        #100;

        // ======================================================
        // GAME 1: WINNING SCENARIO
        // ======================================================
        
        // 1. Press Start -> Expect gen_start pulse
        @(posedge clk); #1;
        btn1_in = 1'b1;
        @(posedge clk); #1;
        
        if (gen_start !== 1'b1) begin 
            $display("[ERROR] gen_start did not pulse after btn1"); 
            error_count = error_count + 1; 
        end
        
        btn1_in = 1'b0;
        
        // 2. Generator finishes -> Expect play_start pulse
        @(posedge clk); #1;
        gen_done = 1'b1;
        @(posedge clk); #1;
        
        if (play_start !== 1'b1) begin 
            $display("[ERROR] play_start did not pulse after gen_done"); 
            error_count = error_count + 1; 
        end
        
        gen_done = 1'b0;
        
        // 3. Player finishes -> Expect input_enable to go HIGH
        @(posedge clk); #1;
        play_done = 1'b1;
        @(posedge clk); #1;
        
        if (input_enable !== 1'b1) begin 
            $display("[ERROR] input_enable did not go high after play_done"); 
            error_count = error_count + 1; 
        end
        
        play_done = 1'b0;
        
        // 4. Rhythm check finishes (WIN) -> Expect input_enable LOW, led2 HIGH
        @(posedge clk); #1;
        
        win_flag = 1'b1;
        check_done = 1'b1;
        
        @(posedge clk); #1;
        
        if (input_enable !== 1'b0) begin 
            $display("[ERROR] input_enable did not clear after check_done"); 
            error_count = error_count + 1; 
        end
        if (led2_out !== 1'b1) begin 
            $display("[ERROR] led2_out did not turn ON after win"); 
            error_count = error_count + 1; 
        end
        
        check_done = 1'b0;

        #100;

        // ======================================================
        // GAME 2: LOSING SCENARIO (To test Win-Streak Break)
        // ======================================================
        
        // 1. Restart game -> Expect led2_out to REMAIN HIGH from streak
        @(posedge clk); #1;
        btn1_in = 1'b1;
        @(posedge clk); #1;
        
        if (led2_out !== 1'b1) begin 
            $display("[ERROR] led2_out prematurely cleared on game restart"); 
            error_count = error_count + 1; 
        end
        
        if (gen_start !== 1'b1) begin 
            $display("[ERROR] gen_start did not pulse on restart"); 
            error_count = error_count + 1; 
        end
        
        btn1_in = 1'b0;
        
        // 2. Advance to Input state (skip checking pulses here to save time)
        @(posedge clk); #1; gen_done = 1'b1;
        @(posedge clk); #1; gen_done = 1'b0;
        
        @(posedge clk); #1; play_done = 1'b1;
        @(posedge clk); #1; play_done = 1'b0;
        
        // 3. Rhythm check finishes (LOSE) -> Expect led2_out to turn OFF
        @(posedge clk); #1;
        win_flag = 1'b0;
        check_done = 1'b1;
        @(posedge clk); #1;
        
        if (led2_out !== 1'b0) begin 
            $display("[ERROR] led2_out did not turn OFF after loss"); 
            error_count = error_count + 1; 
        end
        
        check_done = 1'b0;

        #100;

        // RESULT
        $display("========================================");
        if (error_count == 0) begin
            $display("GAME FSM: TEST SUCCESS");
        end
        else begin
            $display("GAME FSM: TEST FAILED");
            $display("ERROR COUNT = %0d", error_count);
        end
        $display("========================================");

        $finish;
    end
endmodule