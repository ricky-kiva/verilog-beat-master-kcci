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


module tb_beat_player;
    // Set 1 cycle = 10 ns (100 MHz clock)
    // 1000 cycles per "ms" -> 1 "ms" parameter unit = 1 clock cycle
    localparam CLK_FREQ        = 1000;
    localparam TIME_8TH_MS     = 10;   // 10 cycles  = 100 ns
    localparam TIME_4TH_MS     = 20;   // 20 cycles  = 200 ns
    localparam TIME_HALF_MS    = 40;   // 40 cycles  = 400 ns
    localparam TIME_WHOLE_MS   = 10;   // Set to 10 cycles (100 ns) so total sequence easily fits < 1000 ns
    localparam FLASH_TIME_MS   = 2;    // 2 cycles   = 20 ns flash
    localparam CYCLES_PER_MS   = CLK_FREQ / 1000; // 1 cycle
    localparam EXP_FLASH_CYCLES = FLASH_TIME_MS  * CYCLES_PER_MS;
    localparam EXP_8TH_CYCLES   = TIME_8TH_MS    * CYCLES_PER_MS;
    localparam EXP_4TH_CYCLES   = TIME_4TH_MS    * CYCLES_PER_MS;
    localparam EXP_HALF_CYCLES  = TIME_HALF_MS   * CYCLES_PER_MS;
    localparam EXP_WHOLE_CYCLES = TIME_WHOLE_MS  * CYCLES_PER_MS;

    reg         clk;
    reg         reset;
    reg         start;
    reg  [23:0] beat_sequence;
    reg  [3:0]  beat_count;

    wire        led_out;
    wire        done;

    integer     error_count;
    integer     flash_high_time;
    integer     period_time;
    integer     expected_period;
    
    beat_player #(
        .CLK_FREQ(CLK_FREQ),
        .TIME_8TH_MS(TIME_8TH_MS),
        .TIME_4TH_MS(TIME_4TH_MS),
        .TIME_HALF_MS(TIME_HALF_MS),
        .TIME_WHOLE_MS(TIME_WHOLE_MS),
        .FLASH_TIME_MS(FLASH_TIME_MS)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .beat_sequence(beat_sequence),
        .beat_count(beat_count),
        .led_out(led_out),
        .done(done)
    );
    
    // 10 ns clock period (5 ns high / 5 ns low)
    always #5 clk = ~clk;
    
    task check_beat(
        input [1:0] beat_code,
        input integer beat_num
    );
        begin
            case (beat_code)
                2'b00: expected_period = EXP_8TH_CYCLES;
                2'b01: expected_period = EXP_4TH_CYCLES;
                2'b10: expected_period = EXP_HALF_CYCLES;
                2'b11: expected_period = EXP_WHOLE_CYCLES;
            endcase

            // Wait synchronously for LED to turn ON
            while (led_out !== 1'b1) @(posedge clk);
            
            flash_high_time = 0;
            period_time     = 0;

            // Measure how long LED stays high (synchronous clock count)
            while (led_out === 1'b1) begin
                flash_high_time = flash_high_time + 1;
                period_time     = period_time + 1;
                @(posedge clk);
            end

            // Check flash duration (allow +/- 1 clock cycle tolerance)
            if (flash_high_time < (EXP_FLASH_CYCLES - 1) || flash_high_time > (EXP_FLASH_CYCLES + 1)) begin
                $display("[ERROR] Beat %0d: Flash duration mismatch. Expected: %0d cycles, Got: %0d cycles",
                         beat_num, EXP_FLASH_CYCLES, flash_high_time);
                error_count = error_count + 1;
            end

            // Measure remaining low time until either next beat starts or done asserts
            while (led_out === 1'b0 && done === 1'b0) begin
                period_time = period_time + 1;
                @(posedge clk);
            end

            // Check total beat note duration (allow +/- 1 clock cycle tolerance)
            if (period_time < (expected_period - 1) || period_time > (expected_period + 1)) begin
                $display("[ERROR] Beat %0d (Code %b): Note duration mismatch. Expected: %0d cycles, Got: %0d cycles",
                         beat_num, beat_code, expected_period, period_time);
                error_count = error_count + 1;
            end
        end         
    endtask
    
    initial begin
        clk           = 0;
        reset         = 1;
        start         = 0;
        beat_sequence = 16'd0;
        beat_count    = 4'd0;
        error_count   = 0;
    
        #20;
        @(posedge clk);
        reset = 0;
        #20;
        
        // TEST CASE 1: Play 4 distinct beats
        @(posedge clk);
        
        beat_count    = 4'd4;
        beat_sequence = 16'b00_00_00_00_11_10_01_00;
        start         = 1'b1;
        
        @(posedge clk);
        start         = 1'b0;

        // Monitor each note
        // Sequence total duration: 10 + 20 + 40 + 10 = 80 cycles = 800 ns
        check_beat(2'b00, 0);
        check_beat(2'b01, 1);
        check_beat(2'b10, 2);
        check_beat(2'b11, 3);

        // Verify done signal asserts
        if (done !== 1'b1) begin
            while (done !== 1'b1) @(posedge clk);
        end
        
        @(posedge clk);

        // Verify it returns to IDLE after done
        if (uut.state !== 2'd0) begin
            $display("[ERROR] State did not return to IDLE after completion.");
            error_count = error_count + 1;
        end
        
        #20;

        // RESULT
        $display("========================================");
        if (error_count == 0) begin
            $display("BEAT PLAYER: TEST SUCCESS");
        end
        else begin
            $display("BEAT PLAYER: TEST FAILED");
            $display("ERROR COUNT = %0d", error_count);
        end
        $display("========================================");

        $finish;
    end   
endmodule