`timescale 1ns / 1ps

module restoringDividerFinal_tb;

    // Inputs
    logic clk = 0;
    logic rst;
    logic start;
    logic toggle;
    logic push;
    logic [15:0] user_input;

    // Outputs
    logic valid;
    logic [6:0] seg;
    logic [7:0] an;

    // Internal access
    logic [15:0] expected_quotient, expected_remainder;

    // Instantiate the DUT (Device Under Test)
    restoringDividerFinal dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .toggle(toggle),
        .push(push),
        .user_input(user_input),
        .valid(valid),
        .seg(seg),
        .an(an)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Task to perform division test
    task perform_division_test(input [15:0] dividend, input [15:0] divisor);
        begin
            // Reset
            rst = 1; @(posedge clk); rst = 0;

            // Load dividend
            toggle = 0;   // 0 for dividend
            user_input = dividend;
            push = 1; @(posedge clk); push = 0;

            // Load divisor
            toggle = 1;   // 1 for divisor
            user_input = divisor;
            push = 1; @(posedge clk); push = 0;

            // Start division
            start = 1; @(posedge clk); start = 0;

            // Wait for completion
            wait(valid);

            // Expected values
            if (divisor == 0) begin
                expected_quotient = 0;
                expected_remainder = dividend;
            end else begin
                expected_quotient = dividend / divisor;
                expected_remainder = dividend % divisor;
            end

            // Print results
            $display("Test: %0d / %0d", dividend, divisor);
            $display("Expected Quotient = %0d, Remainder = %0d", expected_quotient, expected_remainder);
            $display("Actual   Quotient = %0d, Remainder = %0d", dut.quotient, dut.remainder);
            
            if ((dut.quotient === expected_quotient) && (dut.remainder === expected_remainder))
                $display("Result: PASS\n");
            else
                $display("Result: FAIL\n");

            #100;
        end
    endtask

    // Test sequence
    initial begin
        // Initial values
        start = 0;
        toggle = 0;
        push = 0;
        user_input = 0;

        // Wait a moment
        #20;

        // Run multiple test cases
        perform_division_test(25, 3);
        perform_division_test(100, 10);
        perform_division_test(50, 7);
        perform_division_test(12345, 123);
        perform_division_test(65535, 1);
        perform_division_test(1234, 0);    // Divide-by-zero test

        $display("All tests completed.");
        $finish;
    end

endmodule
