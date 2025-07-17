`timescale 1ns / 1ps

module sevenSegController_tb;

    // Inputs
    logic clk;
    logic rst;
    logic [15:0] remainder;
    logic [15:0] quotient;

    // Outputs
    logic [6:0] seg;
    logic [7:0] an;

    // Instantiate DUT
    sevenSegController dut (
        .clk(clk),
        .rst(rst),
        .remainder(remainder),
        .quotient(quotient),
        .seg(seg),
        .an(an)
    );

    // Clock generation (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Helper to display current digit
    function [7*8:1] seg_to_ascii(input [6:0] seg_bits);
        case (seg_bits)
            7'b1000000: seg_to_ascii = "0";
            7'b1111001: seg_to_ascii = "1";
            7'b0100100: seg_to_ascii = "2";
            7'b0110000: seg_to_ascii = "3";
            7'b0011001: seg_to_ascii = "4";
            7'b0010010: seg_to_ascii = "5";
            7'b0000010: seg_to_ascii = "6";
            7'b1111000: seg_to_ascii = "7";
            7'b0000000: seg_to_ascii = "8";
            7'b0011000: seg_to_ascii = "9";
            7'b0001000: seg_to_ascii = "A";
            7'b0000011: seg_to_ascii = "B";
            7'b1000110: seg_to_ascii = "C";
            7'b0100001: seg_to_ascii = "D";
            7'b0000110: seg_to_ascii = "E";
            7'b0001110: seg_to_ascii = "F";
            default:    seg_to_ascii = "-";
        endcase
    endfunction

    initial begin
        $display("Starting 7-segment display test...");

        // Initial values
        rst = 1;
        remainder = 16'h1234;
        quotient  = 16'h00AB;

        // Reset pulse
        repeat (2) @(posedge clk);
        rst = 0;

        // Wait long enough to see all digits cycle
        repeat (1000) begin
            @(posedge clk);
            $display("an = %b, seg = %s", an, seg_to_ascii(seg));
        end

        $display("Simulation complete.");
        #5000;
        rst = 1;
        #10;
        rst = 0;
        #5000;
        $finish;
    end

endmodule
