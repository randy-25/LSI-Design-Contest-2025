module exponential#
(
    parameter input_integer_width = 10,
    parameter input_fraction_width = 10,
    parameter output_integer_width = 10,
    parameter output_fraction_width = 10
)
(
    input clk,
    input reset, 
    input enable,
    input signed [input_integer_width + input_fraction_width - 1:0] data_input,
    output reg signed [output_integer_width + output_fraction_width - 1:0] data_output,
    output reg done
);

// LUT Parameters
reg [13:0] exp_lut_address = 14'b11111111111111; // Address for exponential LUT
wire [19:0] exp_lut_data; // Output data from LUT

// Instantiate the LUT
exp_mem exp_lut (
    .clka(clk),
    .addra(exp_lut_address),
    .dina(20'b0),
    .douta(exp_lut_data),
    .wea(1'b0)
);

// Offset for input range adjustment
localparam signed [13:0] OFFSET = 14'b0110_1110111010; // Positive version of -6.931471805599453 in Q10.10
localparam signed [19:0] MIN_INPUT = 20'b1111111001_0001000110; // -6.931471805599453 in Q10.10
localparam signed [19:0] MAX_INPUT = 20'b0000000110_0011110100; // 6.238322717689056 in Q10.10

reg [13:0] input_sliced;
reg [2:0] delay_counter = 3'b000;
reg [2:0] state = 0;

always @(posedge clk) begin
    if (reset) begin
        // Reset all outputs and states
        done <= 0;
        exp_lut_address <= 14'b11111111111111;
        data_output <= 20'b0000000000_0000000000;
        delay_counter <= 0;
        state <= 0;
    end else begin
        case (state)
            0: begin
                if (enable) begin
                    input_sliced = data_input[13:0];
                    if (data_input < ($signed({MIN_INPUT}))) begin
                        // Clamp output to minimum value
                        data_output <= 20'b0000000000_0000000001; // Smallest Q10.10 value
                        state <= 2;
                    end else if (data_input > ($signed({MAX_INPUT}))) begin
                        // Clamp output to maximum value
                        data_output <= 20'b0111111111_1111111111; // Largest Q10.10 value
                        state <= 2;
                    end else begin
                        // Adjust input and compute LUT address
                        // Shift for LUT index
                        exp_lut_address <= input_sliced + OFFSET;
                        delay_counter <= 0;
                        state <= 1;
                    end
                end else begin
                    state <= 0;
                    delay_counter <= 0;
                end
            end

            1: begin
                if (delay_counter < 2) begin
                    // Wait for LUT read delay
                    delay_counter <= delay_counter + 1;
                    state <= 1;
                end else begin
                    // Read LUT data
                    data_output <= exp_lut_data;
                    state <= 2;
                end
            end

            2: begin
                // Signal completion
                done <= 1;
                state <= 2;
            end
        endcase
    end
end

endmodule