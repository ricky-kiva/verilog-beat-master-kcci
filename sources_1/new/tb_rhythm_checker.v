`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 27.09.2026 11:28:04
// Design Name: 
// Module Name: tb_rhythm_checker
// Project Name: Beat Master
// Target Devices: Zybo Z7-10
// Tool Versions: 2026.1
// Description: Self-checking testbench verifying the proportional (25%) tolerance
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_rhythm_checker();
    reg clk;
    reg reset;
    reg enable;
    
    reg [15:0] tap_interval_ms;
    reg        tap_valid;
    
    reg [23:0] beat_sequence;
    reg [3:0]  beat_count;
    
    wire check_done;
    wire win_flag;

    integer error_count;

    rhythm_checker #(
        .TIME_8TH_MS(250),
        .TIME_4TH_MS(500),
        .TIME_HALF_MS(1000),
        .TIME_WHOLE_MS(2000)
    ) uut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .tap_interval_ms(tap_interval_ms),
        .tap_valid(tap_valid),
        .beat_sequence(beat_sequence),
        .beat_count(beat_count),
        .check_done(check_done),
        .win_flag(win_flag)
    );

    // 100 MHz clock -> 10ns period
    always #5 clk = ~clk;

    // Task to simulate an interval arriving from tap_detector
    task send_interval(input [15:0] ms);
        begin
            @(posedge clk);
            tap_interval_ms = ms;
            tap_valid = 1'b1;
            @(posedge clk);
            tap_valid = 1'b0;
            @(posedge clk);
        end
    endtask

    // Task to gracefully reset the module between test cases
    task soft_reset();
        begin
            @(posedge clk);
            enable = 1'b0;
            // Wait 5 clock cycles to ensure rhythm_checker registers the reset
            repeat(5) @(posedge clk);
        end
    endtask

    initial begin
        clk             = 0;
        reset           = 1;
        enable          = 0;
        tap_interval_ms = 0;
        tap_valid       = 0;
        beat_sequence   = 0;
        beat_count      = 0;
        error_count     = 0;

        repeat(10) @(posedge clk);
        reset = 0;
        repeat(10) @(posedge clk);

        // ======================================================
        // TEST CASE 1: Perfect timing
        // Sequence: 8th, Quarter, Half, Whole (00, 01, 10, 11)
        // Expected: 250, 500, 1000, 2000
        // ======================================================
        beat_count    = 4;
        beat_sequence = 16'b11_10_01_00; 
        
        @(posedge clk);
        enable = 1'b1;
        
        send_interval(250);
        if (check_done !== 1'b0) begin $display("[ERROR] TC1: Failed early at 8th"); error_count = error_count + 1; end
        
        send_interval(500);
        if (check_done !== 1'b0) begin $display("[ERROR] TC1: Failed early at 4th"); error_count = error_count + 1; end
        
        send_interval(1000);
        if (check_done !== 1'b0) begin $display("[ERROR] TC1: Failed early at Half"); error_count = error_count + 1; end
        
        send_interval(2000);
        if (check_done !== 1'b1 || win_flag !== 1'b1) begin 
            $display("[ERROR] TC1: Expected WIN but got done=%b win=%b", check_done, win_flag); 
            error_count = error_count + 1; 
        end
        
        soft_reset();

        // ======================================================
        // TEST CASE 2: Near-bounds timing (Tolerance = +/- 25%)
        // 8th (250)    => 250/4 = 62   => Window: 188 to 312
        // 4th (500)    => 500/4 = 125  => Window: 375 to 625
        // Half (1000)  => 1000/4 = 250 => Window: 750 to 1250
        // Whole (2000) => 2000/4 = 500 => Window: 1500 to 2500
        // ======================================================
        beat_count    = 4;
        beat_sequence = 16'b11_10_01_00; 
        
        @(posedge clk);
        enable = 1'b1;
        
        send_interval(312); // 8th Max allowable
        if (check_done !== 1'b0) begin $display("[ERROR] TC2: Failed at bounds 312"); error_count = error_count + 1; end
        
        send_interval(375); // 4th Min allowable
        if (check_done !== 1'b0) begin $display("[ERROR] TC2: Failed at bounds 375"); error_count = error_count + 1; end
        
        send_interval(1250); // Half Max allowable
        if (check_done !== 1'b0) begin $display("[ERROR] TC2: Failed at bounds 1250"); error_count = error_count + 1; end
        
        send_interval(1500); // Whole Min allowable
        if (check_done !== 1'b1 || win_flag !== 1'b1) begin 
            $display("[ERROR] TC2: Expected WIN at bounds"); 
            error_count = error_count + 1; 
        end
        
        soft_reset();

        // ======================================================
        // TEST CASE 3: Out of bounds timing (Failure)
        // Quarter (500)    => Window: 375 to 625
        // 8th (250)        => Window: 188 to 312
        // Input: 500, 313
        // ======================================================
        beat_count    = 2;
        beat_sequence = 16'b00_00_00_01; // Quarter, 8th 
        
        @(posedge clk);
        enable = 1'b1;
        
        send_interval(500);
        if (check_done !== 1'b0) begin $display("[ERROR] TC3: Failed on valid 500"); error_count = error_count + 1; end
        
        send_interval(313); // 250 + 63 (Outside 25% tolerance by 1ms)
        if (check_done !== 1'b1 || win_flag !== 1'b0) begin 
            $display("[ERROR] TC3: Expected LOSE on 313, got done=%b win=%b", check_done, win_flag); 
            error_count = error_count + 1; 
        end
        
        soft_reset();

        // RESULT
        $display("========================================");
        if (error_count == 0) begin
            $display("RHYTHM CHECKER: TEST SUCCESS");
        end
        else begin
            $display("RHYTHM CHECKER: TEST FAILED");
            $display("ERROR COUNT = %0d", error_count);
        end
        $display("========================================");

        $finish;
    end
endmodule