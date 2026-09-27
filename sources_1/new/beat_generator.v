`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 24.09.2026 23:25:29
// Design Name: 
// Module Name: beat_generator
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


module beat_generator(
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire        sw1,
    input  wire        sw2,
    input  wire        sw3,
    output reg [23:0]  beat_sequence,
    output reg [3:0]   beat_count,
    output reg         done
);
    // 8-bit Linear Feedback Shift Register
    reg [7:0] lfsr;

    // Index of the beat currently being generated
    reg [3:0] beat_index;

    // Number of beats to generate
    reg [3:0] target_count;

    // Generation in progress
    reg generating;
    
    // Limit whole note
    reg [1:0] whole_count;

    // LFSR feedback bit
    wire random_bit;

    assign random_bit = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];
    
    always @(posedge clk) begin
        if (reset) begin
            lfsr          <= 8'b10110101;
            beat_sequence <= 24'd0;
            beat_count    <= 4'd0;
            beat_index    <= 4'd0;
            target_count  <= 4'd0;
            whole_count   <= 2'd0;
            generating    <= 1'b0;
            done          <= 1'b0;
        end
        else begin
            // Free-running LFSR: runs continuously on every clock cycle
            lfsr <= {lfsr[6:0], random_bit};
            
            if (start && !generating) begin
                if (sw3) begin
                    target_count <= 4'd12;
                end
                else if (sw2) begin
                    target_count <= 4'd8;
                end
                else if (sw1) begin
                    target_count <= 4'd4;
                end
                else begin
                    target_count <= 4'd4;
                end

                beat_sequence <= 24'd0;   // Fixed width: 24 bits
                beat_index    <= 4'd0;
                beat_count    <= 4'd0;
                whole_count   <= 2'd0;   // Reset counter for each new round

                generating    <= 1'b1;
                done          <= 1'b0;
            end
            else if (generating) begin
                // If 2'b11 (whole note) appears more than twice, downgrade to 2'b10 (half note)
                if (lfsr[1:0] == 2'b11) begin
                    if (whole_count < 2'd2) begin
                        beat_sequence[beat_index*2 +: 2] <= 2'b11;
                        whole_count <= whole_count + 1'b1;
                    end else begin
                        beat_sequence[beat_index*2 +: 2] <= 2'b10;
                    end
                end else begin
                    beat_sequence[beat_index*2 +: 2] <= lfsr[1:0];
                end

                // Advance beat counters
                beat_index <= beat_index + 1'b1;
                beat_count <= beat_index + 1'b1;

                // Check if this was the final beat
                if (beat_index + 1 >= target_count) begin
                    generating <= 1'b0;
                    done       <= 1'b1;
                end
            end
        end
    end
endmodule
