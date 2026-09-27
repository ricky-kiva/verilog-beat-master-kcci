`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 27.09.2026
// Design Name: 
// Module Name: tb_tap_detector
// Project Name: Beat Master
// Target Devices: Zybo Z7-10
// Tool Versions: Vivado 2026.1
// Description: Self-checking testbench for tap_detector verifying pulse, intervals,
//              and enable/disable safety resets.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_tap_detector();
    // Scale down so 1 millisecond = 1 clock cycle
    localparam CLK_FREQ = 1000; 

    reg  clk;
    reg  reset;
    reg  enable;
    reg  tap_in;
    
    wire        tap_pulse;
    wire [15:0] tap_interval_ms;
    wire        tap_valid;
    wire        first_tap_detected;

    integer error_count;

    tap_detector #(
        .CLK_FREQ(CLK_FREQ)
    ) uut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .tap_in(tap_in),
        .tap_pulse(tap_pulse),
        .tap_interval_ms(tap_interval_ms),
        .tap_valid(tap_valid),
        .first_tap_detected(first_tap_detected)
    );

    // 10 ns clock (100 MHz)
    always #5 clk = ~clk;

    // Task 1: Properly align the press and release to clock edges (consumes 2 cycles)
    task press_button();
        begin
            @(posedge clk);
            tap_in <= 1'b1;
            @(posedge clk);
            tap_in <= 1'b0;
        end
    endtask

    // Task 2: Wait an exact amount of simulated milliseconds
    task wait_ms(input integer ms);
        begin
            // press_button uses cycles to execute. To ensure the gap between 
            // the exact moment of edge detection is perfect, it subtracts 1.
            repeat(ms - 1) @(posedge clk);
        end
    endtask

    initial begin
        clk         <= 0;
        reset       <= 1;
        enable      <= 0;
        tap_in      <= 0;
        error_count = 0;

        // Brief reset pulse
        repeat(5) @(posedge clk);
        reset <= 0;
        repeat(2) @(posedge clk);

        // ----------------------------------------------------
        // TEST 1: tap_in while disabled
        // ----------------------------------------------------
        press_button();
        
        #1; // Wait 1ns for module to process the edge
        
        if (tap_pulse !== 1'b0 || first_tap_detected !== 1'b0) begin
            $display("[ERROR] Triggered while disabled.");
            error_count = error_count + 1;
        end

        // ----------------------------------------------------
        // TEST 2: Enable & Tap 1 (Anchor)
        // ----------------------------------------------------
        enable <= 1'b1;
        
        press_button();
        
        #1;
        
        if (first_tap_detected !== 1'b1) begin
            $display("[ERROR] first_tap_detected not asserted on tap 1.");
            error_count = error_count + 1;
        end

        // ----------------------------------------------------
        // TEST 3: Tap 2 (Check 10 ms interval)
        // ----------------------------------------------------
        wait_ms(10);
        press_button();
        
        #1;
        
        if (tap_interval_ms !== 16'd10) begin
            $display("[ERROR] 10 ms mismatch. Got: %0d ms", tap_interval_ms);
            error_count = error_count + 1;
        end

        // ----------------------------------------------------
        // TEST 4: Tap 3 (Check 20 ms interval)
        // ----------------------------------------------------
        wait_ms(20);
        press_button();
        
        #1;
        
        if (tap_interval_ms !== 16'd20) begin
            $display("[ERROR] 20 ms mismatch. Got: %0d ms", tap_interval_ms);
            error_count = error_count + 1;
        end

        // ----------------------------------------------------
        // TEST 5: Tap 4 (Check 15 ms interval)
        // ----------------------------------------------------
        wait_ms(15);
        press_button();
        
        #1;
        
        if (tap_interval_ms !== 16'd15) begin
            $display("[ERROR] 15 ms mismatch. Got: %0d ms", tap_interval_ms);
            error_count = error_count + 1;
        end

        // ----------------------------------------------------
        // TEST 6: Verify that pulling enable LOW clears all state registers
        // ----------------------------------------------------
        enable <= 1'b0;
        
        @(posedge clk); // Give module 1 cycle to evaluate disable reset
        #1;
        
        if (first_tap_detected !== 1'b0 || uut.tap_interval_ms !== 16'd0) begin
            $display("[ERROR] State did not clear when disabled.");
            error_count = error_count + 1;
        end

        // RESULT
        $display("========================================");
        if (error_count == 0) begin
            $display("TAP DETECTOR: TEST SUCCESS");
        end
        else begin
            $display("TAP DETECTOR: TEST FAILED");
            $display("ERROR COUNT = %0d", error_count);
        end
        $display("========================================");

        $finish; 
    end
endmodule