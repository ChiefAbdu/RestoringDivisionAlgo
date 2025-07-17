module sevenSegController (
    input  logic clk,
    input  logic rst,
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
                end else begin  // Assigns Value to the Registers
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
        case (active_sel)
    
            3'd0: begin an = 8'b11111110; digit = r_digit0; end
            3'd1: begin an = 8'b11111101; digit = r_digit1; end
            3'd2: begin an = 8'b11111011; digit = r_digit2; end
            3'd3: begin an = 8'b11110111; digit = r_digit3; end
            3'd4: begin an = 8'b11101111; digit = q_digit0; end
            3'd5: begin an = 8'b11011111; digit = q_digit1; end
            3'd6: begin an = 8'b10111111; digit = q_digit2; end
            3'd7: begin an = 8'b01111111; digit = q_digit3; end
                    
        endcase

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
