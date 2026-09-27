`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 24.09.2026 21:54:12
// Design Name: 
// Module Name: tb_button_debounce
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


module tb_button_debounce;
    reg clk;
    reg reset;
    reg button_in;
    wire button_out;
    
    integer error_count;
    
    localparam DEBOUNCE_COUNT = 5;
    
    button_debounce #(
        .DEBOUNCE_COUNT(DEBOUNCE_COUNT)
    ) dut (
        .clk(clk),
        .reset(reset),
        .button_in(button_in),
        .button_out(button_out)
    );
    
    always #5 clk = ~clk;
    
    task check_output;
        input expected;
        begin
            #1;

            if (button_out !== expected) begin
                $display("ERROR: Expected %b, Got %b at time %0t",
                         expected, button_out, $time);
                error_count = error_count + 1;
            end
        end
    endtask
    
    initial begin
        reset = 1;
        clk = 0;
        button_in = 0;
        error_count = 0;
        
        #20;
        reset = 0;
        
        // TEST 1: Button initially released
        check_output(0);
        
        // TEST 2: Button pressed
        button_in = 1;
        
        // Wait for debounce
        repeat (DEBOUNCE_COUNT + 5) @(posedge clk);
        
        check_output(1);
        
        // TEST 3: Button released
        button_in = 0;
        
        // Wait for debounce
        repeat (DEBOUNCE_COUNT + 5) @(posedge clk);
        
        check_output(0);
        
        // TEST 4: Simulate button bouncing
        button_in = 1;
        @(posedge clk);

        button_in = 0;
        @(posedge clk);

        button_in = 1;
        @(posedge clk);

        button_in = 0;
        @(posedge clk);

        button_in = 1;

        // Keep button stable
        repeat (DEBOUNCE_COUNT + 5) @(posedge clk);

        check_output(1);
        
        // TEST 5: Release button
        button_in = 0;
        
        repeat (DEBOUNCE_COUNT + 5) @(posedge clk);
        
        check_output(0);
        
        // RESULT
        $display("========================================");
        if (error_count == 0) begin
            $display("BUTTON DEBOUNCE: TEST SUCCESS");
        end
        else begin
            $display("BUTTON DEBOUNCE: TEST FAILED");
            $display("ERROR COUNT = %0d", error_count);
        end
        
        $finish;
    end
endmodule
