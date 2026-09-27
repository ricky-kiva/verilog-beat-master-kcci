`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 27.09.2026 13:56:42
// Design Name: 
// Module Name: tb_top
// Project Name: Beat Master
// Target Devices: Zybo Z7-10
// Tool Versions: Vivado 2026.1
// Description: Integration testbench for the top module simulating a full game.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// NOTE: Run simulation with `run all` on "Tcl Console"

module tb_top();

    // 125 MHz clock -> 8ns period
    reg clk;
    always #4 clk = ~clk;

    reg  [2:0] btn;
    reg  [2:0] sw;
    wire [1:0] led;

    integer error_count;
    integer i;
    reg [1:0] expected_note;
    integer target_ms;
    integer wait_cycles;

    // Fast simulation parameter overrides (100x faster than real-time)
    localparam SIM_CLK_FREQ  = 1_250_000;
    localparam CYCLES_PER_MS = SIM_CLK_FREQ / 1000; // 1250 cycles = 1 ms
    
    defparam uut.btn1_inst.DEBOUNCE_COUNT = 10;
    defparam uut.btn2_inst.DEBOUNCE_COUNT = 10;
    defparam uut.player_inst.CLK_FREQ     = SIM_CLK_FREQ;
    defparam uut.tap_inst.CLK_FREQ        = SIM_CLK_FREQ;

    top uut (
        .clk(clk),
        .btn(btn),
        .sw(sw),
        .led(led)
    );

    // Reusable task to simulate pressing a button
    task press_button(input integer btn_idx);
        begin
            @(negedge clk);
            btn[btn_idx] = 1'b1;
            repeat(20) @(posedge clk);
            @(negedge clk);
            btn[btn_idx] = 1'b0;
            repeat(20) @(posedge clk);
        end
    endtask

    // Reusable task to play through the sequence accurately (guaranteed WIN)
    task play_winning_game();
        begin
            // Anchor tap: starts the interval timer
            press_button(2);

            // Dynamically match each note duration in the generated sequence
            for (i = 0; i < uut.beat_count; i = i + 1) begin
                expected_note = uut.beat_sequence[i*2 +: 2];
                
                case(expected_note)
                    2'b00: target_ms = 250;
                    2'b01: target_ms = 500;
                    2'b10: target_ms = 1000;
                    2'b11: target_ms = 2000;
                endcase
                
                wait_cycles = target_ms * CYCLES_PER_MS;
                repeat(wait_cycles - 40) @(posedge clk);
                
                press_button(2);
            end
        end
    endtask

    initial begin
        // Initialize
        clk         = 0;
        btn         = 3'b000;
        sw          = 3'b001; // 4-beat mode (sw1)
        error_count = 0;

        // Apply Reset (btn[0])
        @(negedge clk);
        btn[0] = 1'b1;
        repeat(50) @(posedge clk);
        @(negedge clk);
        btn[0] = 1'b0;
        repeat(50) @(posedge clk);

        // ======================================================
        // ROUND 1: FIRST WIN
        // ======================================================
        $display("[INFO] Starting Round 1 (Target: WIN)...");
        press_button(1); // Start game

        // Wait for generation + playback to finish
        wait(uut.fsm_inst.state == 3'd3); // S_INPUT
        repeat(100) @(posedge clk);

        // Tap the rhythm correctly
        play_winning_game();

        // Wait for evaluation
        wait(uut.fsm_inst.state == 3'd4); // S_RESULT
        @(posedge clk); #1;

        if (led[1] !== 1'b1) begin
            $display("[ERROR] Round 1: led[1] did not turn ON after winning.");
            error_count = error_count + 1;
        end else begin
            $display("[INFO] Round 1 PASSED: led[1] is ON.");
        end

        repeat(200) @(posedge clk);

        // ======================================================
        // ROUND 2: SECOND WIN (WIN-STREAK TEST)
        // ======================================================
        $display("[INFO] Starting Round 2 (Target: WIN STREAK)...");
        press_button(1); // Start game again

        // Verify led[1] stays ON while restarting and playing the new rhythm
        @(posedge clk); #1;
        if (led[1] !== 1'b1) begin
            $display("[ERROR] Round 2: led[1] prematurely cleared on game restart.");
            error_count = error_count + 1;
        end

        // Wait for playback to finish
        wait(uut.fsm_inst.state == 3'd3); // S_INPUT
        repeat(100) @(posedge clk);

        // Verify led[1] still held through input phase
        if (led[1] !== 1'b1) begin
            $display("[ERROR] Round 2: led[1] turned off during input phase.");
            error_count = error_count + 1;
        end

        // Tap rhythm correctly again
        play_winning_game();

        // Wait for evaluation
        wait(uut.fsm_inst.state == 3'd4); // S_RESULT
        @(posedge clk); #1;

        if (led[1] !== 1'b1) begin
            $display("[ERROR] Round 2: led[1] failed to stay ON after second win.");
            error_count = error_count + 1;
        end else begin
            $display("[INFO] Round 2 PASSED: Win streak preserved (led[1] remained ON).");
        end

        repeat(200) @(posedge clk);

        // ======================================================
        // ROUND 3: LOSE (STREAK BREAK TEST)
        // ======================================================
        $display("[INFO] Starting Round 3 (Target: LOSE & CLEAR STREAK)...");
        press_button(1); // Start game

        // Verify led[1] is still ON entering round 3
        @(posedge clk); #1;
        if (led[1] !== 1'b1) begin
            $display("[ERROR] Round 3: led[1] prematurely cleared before failing.");
            error_count = error_count + 1;
        end

        // Wait for playback to finish
        wait(uut.fsm_inst.state == 3'd3); // S_INPUT
        repeat(100) @(posedge clk);

        // Anchor tap
        press_button(2);

        // Intentionally tap too early (50 ms vs min possible 187 ms for 8th note)
        repeat(50 * CYCLES_PER_MS) @(posedge clk);
        press_button(2);

        // Wait for evaluation
        wait(uut.fsm_inst.state == 3'd4); // S_RESULT
        @(posedge clk); #1;

        if (led[1] !== 1'b0) begin
            $display("[ERROR] Round 3: led[1] did not turn OFF after losing.");
            error_count = error_count + 1;
        end else begin
            $display("[INFO] Round 3 PASSED: Loss detected, win streak cleared (led[1] is OFF).");
        end

        repeat(200) @(posedge clk);

        // ======================================================
        // ROUND 4: RESTORE WIN STREAK
        // ======================================================
        $display("[INFO] Starting Round 4 (Target: WIN & RESTORE STREAK)...");
        press_button(1); // Start game

        // Verify led[1] is still OFF when restarting (streak was broken)
        @(posedge clk); #1;
        if (led[1] !== 1'b0) begin
            $display("[ERROR] Round 4: led[1] turned ON prematurely on game restart.");
            error_count = error_count + 1;
        end

        // Wait for playback to finish
        wait(uut.fsm_inst.state == 3'd3); // S_INPUT
        repeat(100) @(posedge clk);

        // Tap rhythm correctly again
        play_winning_game();

        // Wait for evaluation
        wait(uut.fsm_inst.state == 3'd4); // S_RESULT
        @(posedge clk); #1;

        if (led[1] !== 1'b1) begin
            $display("[ERROR] Round 4: led[1] did not turn ON after restoring win streak.");
            error_count = error_count + 1;
        end else begin
            $display("[INFO] Round 4 PASSED: Win streak restored (led[1] is ON).");
        end

        repeat(200) @(posedge clk);

        // RESULT
        $display("========================================");
        if (error_count == 0) begin
            $display("TOP MODULE: WIN-WIN-LOSE-WIN TEST SUCCESS");
        end
        else begin
            $display("TOP MODULE: TEST FAILED");
            $display("ERROR COUNT = %0d", error_count);
        end
        $display("========================================");

        $finish;
    end
endmodule