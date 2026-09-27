`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 25.09.2026 00:21:24
// Design Name: 
// Module Name: tb_beat_generator
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


module tb_beat_generator;
    reg clk;
    reg reset;
    reg start;
    reg sw1;
    reg sw2;
    reg sw3;

    wire [23:0] beat_sequence;
    wire [3:0]  beat_count;
    wire        done;
    
    integer error_count = 0;
    
    beat_generator dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .sw1(sw1),
        .sw2(sw2),
        .sw3(sw3),
        .beat_sequence(beat_sequence),
        .beat_count(beat_count),
        .done(done)
    );
    
    always #5 clk = ~clk;
    
    // Test one sequence
    task test_sequence;
        input [2:0] sw_inputs;
        input [3:0] expected_count;
        
        integer i;
        integer whole_note_count;
        begin
            // 1. Reset the module to clear 'done' flag from previous runs
            reset = 1'b1;
            repeat(3) @(posedge clk);
            reset = 1'b0;
            @(posedge clk);
            
            // 2. Set switches and pulse start
            {sw3, sw2, sw1} = sw_inputs;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            
            // 3. Wait until generation is complete
            wait(done == 1'b1);
            @(posedge clk);

            // 4. Validate outputs
            if (beat_count !== expected_count) begin
                $display("ERROR: Expected beat count %0d, Got %0d", 
                         expected_count, beat_count);
                error_count = error_count + 1;
            end
            
            // Using XOR reduction to check for 'x' or 'z' states
            if (^beat_sequence === 1'bx) begin
                $display("ERROR: Beat sequence contains unknown values");
                error_count = error_count + 1;
            end

            // 5. Verify maximum 2 whole notes (2'b11) rule
            whole_note_count = 0;
            for (i = 0; i < expected_count; i = i + 1) begin
                if (beat_sequence[i*2 +: 2] == 2'b11) begin
                    whole_note_count = whole_note_count + 1;
                end
            end

            if (whole_note_count > 2) begin
                $display("ERROR: Sequence contains %0d whole notes (Max allowed is 2)", whole_note_count);
                error_count = error_count + 1;
            end
        end
    endtask
    
    initial begin
        #5000;
        $display("FATAL ERROR: Simulation timed out. A wait condition was never met.");
        $finish;
    end
    
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        start = 0;
        sw1 = 0;
        sw2 = 0;
        sw3 = 0;

        #20;
        
        $display("--- Starting Beat Generator Tests ---");

        // TEST 1: 4 beats (sw1 = 1)
        test_sequence(3'b001, 4'd4);
        $display("Test 1 (4 beats) complete.");

        // TEST 2: 8 beats (sw2 = 1)
        test_sequence(3'b010, 4'd8);
        $display("Test 2 (8 beats) complete.");

        // TEST 3: 12 beats (sw3 = 1)
        test_sequence(3'b100, 4'd12);
        $display("Test 3 (12 beats) complete.");

        // RESULT
        $display("========================================");
        if (error_count == 0) begin
            $display("BEAT GENERATOR: TEST SUCCESS");
        end
        else begin
            $display("BEAT GENERATOR: TEST FAILED");
            $display("ERROR COUNT = %0d", error_count);
        end
        $display("========================================");

        $finish;
    end
endmodule
