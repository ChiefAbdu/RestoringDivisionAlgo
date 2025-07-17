`timescale 1ns / 1ps


module restoringDividerFinal (
    input  logic        clk,                // Clock
    input  logic        rst,                // Active-high reset
    input  logic        start,              // Start Divison once start is give (when the values of Divisor and Dividened are stored)   
    input  logic        toggle_input,       // Switch between Dividened and Divisor Input
    input  logic        push,               // Push Values to the registers
    input  logic        toggle_rq_input,
    input  logic [15:0] user_input,         // Input from User
  
    output logic        valid,              // Indicates When Division is Done
    output logic [6:0]  seg,                // Segments of Seven Segment Display (A-G)
    output logic [7:0]  an,                 // 8 Seven Segment Displays
    output logic        toggle_led,
    output logic        toggle_rq_led
);

    // -----------------------------------------------------------------
    // Debouncing And Toggling of toggle button
    // -----------------------------------------------------------------
    logic [15:0] debounce_counter = 0;
    logic toggle_sync_0 = 0, toggle_sync_1 = 0;
    logic last_state = 0;
    logic toggle = 0;  // This is now the toggled output

    assign toggle_led = toggle;

    // Synchronize toggle button input
    always @(posedge clk) begin
        toggle_sync_0 <= toggle_input;
        toggle_sync_1 <= toggle_sync_0;
    end

    // Toggle logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            toggle <= 0;
            last_state <= 0;
            debounce_counter <= 0;
        end else begin
            if (toggle_sync_1 != last_state) begin
                debounce_counter <= debounce_counter + 1;
                if (debounce_counter == 16'hFFFF) begin
                    last_state <= toggle_sync_1;
                    debounce_counter <= 0;
                    if (toggle_sync_1 == 1) begin
                        toggle <= ~toggle;
                    end
                end
            end else begin
                debounce_counter <= 0;
            end
        end
    end    

    // -----------------------------------------------------------------
    // Debouncing And Toggling of toggle_rq button (UNUSED FOR NOW)
    // -----------------------------------------------------------------
    logic [15:0] debounce_toggle_rq = 0;
    logic toggle_rq_sync_0 = 0, toggle_rq_sync_1 = 0;
    logic last_toggle_rq = 0;
    logic toggle_rq = 0;
    assign toggle_rq_led = toggle_rq;

    // Synchronize toggle_rq button input
    always_ff @(posedge clk) begin
        toggle_rq_sync_0 <= toggle_rq_input;
        toggle_rq_sync_1 <= toggle_rq_sync_0;
    end

    // Toggle logic for toggle_rq button
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            toggle_rq <= 0;
            last_toggle_rq <= 0;
            debounce_toggle_rq <= 0;
        end else begin
            if (toggle_rq_sync_1 != last_toggle_rq) begin
                debounce_toggle_rq <= debounce_toggle_rq + 1;
                if (debounce_toggle_rq == 16'hFFFF) begin
                    last_toggle_rq <= toggle_rq_sync_1;
                    debounce_toggle_rq <= 0;
                    if (toggle_rq_sync_1 == 1)
                        toggle_rq <= ~toggle_rq;
                end
            end else begin
                debounce_toggle_rq <= 0;
            end
        end
    end


    // -----------------------------------------------------------------
    // Restoring Division Algorithim Main Module
    // -----------------------------------------------------------------

  logic [15:0] quotient;
  logic [15:0] remainder;

    // State encoding
    typedef enum logic {
        IDLE,         // 1'b0
        DIVIDE        // 1'b1
    } state_t;

    state_t current_state, next_state;

    // 32-bit combined register: [31:16] for remainder (accumulator), [15:0] for quotient
    logic [31:0] combined_reg, next_combined_reg;
    logic [31:0] shifted_reg, temp_reg;

    // 5-bit counter to iterate division steps
    logic [4:0] iteration_count, next_iteration_count;

    // Valid output control
    logic next_valid;

    assign remainder = combined_reg[31:16];
    assign quotient  = combined_reg[15:0];

    logic [15:0] divisor; 
    logic [15:0] dividend;


    always_ff@(posedge clk or posedge rst) begin
        if (rst) begin                          // Resets The Divisor and Dividened Stored in Registers
            divisor <= 16'd0;
            dividend <= 16'd0;
        end else if (push) begin               // Push the value onto the Registers
            if (toggle) begin                  // Switches Between Divisor and Dividened 
                divisor <= user_input;
            end else begin
                dividend <= user_input;
            end        
        end
    end



    // Sequential logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin                                  // Resets the Registers 
            combined_reg     <= 32'd0;
            current_state    <= IDLE;
            iteration_count  <= 5'd0;
            valid            <= 1'b0;
        end else begin                                  // Switch to Next state if no Reset
            combined_reg     <= next_combined_reg;      // Accumulator [M:Q]
            current_state    <= next_state;             // IDLE or DIVIDE 
            iteration_count  <= next_iteration_count;   // Number of iterations
            valid            <= next_valid;             // Checks if iterations == 0
        end
    end

    // Combinational next-state and data logic
    always_comb begin
        // Default assignments
        next_state           = current_state;
        next_combined_reg    = combined_reg;  
        next_iteration_count = iteration_count;
        next_valid           = 1'b0;

        case (current_state)
            IDLE: begin
                next_iteration_count = 5'd0;
                if (start) begin
                    if (divisor == 16'd0) begin                 // Division by 0 ERROr
                        next_state        = IDLE;
                        next_combined_reg = {dividend, 16'd0};  // Remainder = dividend, Quotient = 0
                        next_valid        = 1'b1;               // signal valid even though invalid op
                    end else begin
                        next_state        = DIVIDE;             // Stay in the State
                        next_combined_reg = {16'd0, dividend};  // Zero extend accumulator
                    end
                end else begin
                    next_state        = IDLE;                   // If No Start input, Stay in IDLE state
                    next_combined_reg = 32'd0;                  // No Update in Accumulator
                end
            end


            DIVIDE: begin                                       
                // Step 1: Left shift combined register
                shifted_reg = combined_reg << 1;

                // Step 2: Subtract divisor from upper nibble (accumulator)
                temp_reg = {shifted_reg[31:16] - divisor, shifted_reg[15:0]};

                // Step 3: Check sign and restore if necessary
                if (temp_reg[31]) begin
                    // Restore: keep original and set quotient LSB to 0
                    next_combined_reg = {shifted_reg[31:16], shifted_reg[15:1], 1'b0};
                end else begin
                    // Keep subtraction result and set quotient LSB to 1
                    next_combined_reg = {temp_reg[31:16], shifted_reg[15:1], 1'b1};
                end

                // Step 4: Counter and completion check
                next_iteration_count = iteration_count + 1;

                if (iteration_count == 5'd15) begin  // After 16 cycles
                    next_state = IDLE;
                    next_valid = 1'b1;
                end else begin
                    next_state = DIVIDE;
                    next_valid = 1'b0;
                end
            end
        endcase
    end

    sevenSegController disp (
        .clk(clk),
        .rst(rst),
        .remainder(remainder),
        .quotient(quotient),
        .seg(seg),
        .an(an),
        .valid(valid),
        .toggle_rq(toggle_rq)
    );




endmodule

module sevenSegController (
    input  logic clk,
    input  logic rst,
    input  logic valid,
    input  logic toggle_rq,
    input  logic [15:0] remainder,
    input  logic [15:0] quotient,
    output logic [6:0] seg,
    output logic [7:0] an
);

    logic clk_100Hz;   
    logic [3:0] digit;
    logic [2:0] active_sel;
    logic [16:0] clk_div_count = 0;
    logic [3:0] r_digit0,r_digit1,r_digit2,r_digit3; // Digit 0 is Most Significat, Digit 3 is Least Significant for remainder
    logic [3:0] q_digit0,q_digit1,q_digit2,q_digit3; // Digit 0 is Most Significat, Digit 3 is Least Significant for quoitent


        always_ff@(posedge clk or posedge rst) begin
                if(rst) begin  // Resets The register to Hold 0
                        r_digit0 <= 4'h0;  
                        r_digit1 <= 4'h0;
                        r_digit2 <= 4'h0;
                        r_digit3 <= 4'h0;  
                
                        q_digit0 <= 4'h0;  
                        q_digit1 <= 4'h0;
                        q_digit2 <= 4'h0;
                        q_digit3 <= 4'h0;
                end else if (valid) begin  // Assigns Value to the Registers
                        r_digit3 <= remainder[15:12];  //MSB
                        r_digit2 <= remainder[11:8];
                        r_digit1 <= remainder[7:4];
                        r_digit0 <= remainder[3:0];    //LSB
                
                        q_digit3 <= quotient[15:12];   // MSB
                        q_digit2 <= quotient[11:8];
                        q_digit1 <= quotient[7:4];
                        q_digit0 <= quotient[3:0];     // LSB
                end
        end
       

        always_ff @(posedge clk or posedge rst) begin 
            if (rst) begin
                clk_div_count <= 0;
                clk_100Hz <= 0;
            end else if (clk_div_count == 10) begin
                clk_div_count <= 0;
                clk_100Hz <= ~clk_100Hz;
            end else begin
                clk_div_count <= clk_div_count + 1;
            end
        end

        always_ff @(posedge clk_100Hz or posedge rst) begin
            if (rst) begin
                active_sel <= 0;
            end else begin
                active_sel <= active_sel + 1;
            end
        end


    always_comb begin
        if(toggle_rq)begin
            case (active_sel)
    
                3'd0: begin an = 8'b11111110; digit = r_digit0; end
                3'd1: begin an = 8'b11111101; digit = r_digit1; end
                3'd2: begin an = 8'b11111011; digit = r_digit2; end
                3'd3: begin an = 8'b11110111; digit = r_digit3; end
                3'd4: begin an = 8'b11101111; digit; end
                3'd5: begin an = 8'b11011111; digit; end
                3'd6: begin an = 8'b10111111; digit; end
                3'd7: begin an = 8'b01111111; digit = 4'hA; end
                        
            endcase
        end else begin
            case (active_sel)
    
                3'd0: begin an = 8'b11111110; digit = r_digit0; end
                3'd1: begin an = 8'b11111101; digit = r_digit1; end
                3'd2: begin an = 8'b11111011; digit = r_digit2; end
                3'd3: begin an = 8'b11110111; digit = r_digit3; end
                3'd4: begin an = 8'b11101111; digit; end
                3'd5: begin an = 8'b11011111; digit; end
                3'd6: begin an = 8'b10111111; digit; end
                3'd7: begin an = 8'b01111111; digit = 4'hB end
                        
            endcase
        end

        case (digit)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0011000;
            4'hA: seg = 7'b0001000;  // A
            4'hB: seg = 7'b0000011;  // B
            4'hC: seg = 7'b1000110;  // C
            4'hD: seg = 7'b0100001;  // D
            4'hE: seg = 7'b0000110;  // E
            4'hF: seg = 7'b0001110;  // F
            default: seg = 7'b0111111; // -
        endcase
    end

endmodule

