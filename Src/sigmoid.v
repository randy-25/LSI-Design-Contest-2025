module sigmoid#
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
reg [13:0] sigmoid_lut_address = 14'b11111111111111;
wire [10:0] sigmoid_lut_data;

sigmoid_mem sigmoid_lut (
    .clka(clk),
    .addra(sigmoid_lut_address),
    .dina(20'b0),
    .douta(sigmoid_lut_data),
    .wea(1'b0)
);

reg [13:0] input_sliced;

reg [2:0] delay_counter = 3'b000;
reg [2:0] state=0;

always @(posedge clk) begin
    if (reset) begin
        done <= 0;
        sigmoid_lut_address <= 14'b11111111111111;
        data_output <= 20'b0000000000_0000000000;
        delay_counter <= 0;
        state <= 0;
    end else begin
        case (state) 
            0: begin
               if(enable) begin
                    input_sliced = data_input[13:0];
                    if (data_input < ($signed({20'b1111111100_0000000000}))) begin
                        data_output <= {20'b0000000000_0000000000};
                        state <= 2;
                    end else if (data_input > ($signed({20'b0000000100_0000000000}))) begin
                        data_output <= {20'b0000000001_0000000000};
                        state <= 2;
                    end else begin
                        state <= 1;
                        delay_counter = 0;
                        sigmoid_lut_address = input_sliced + 14'b0100_0000000000;
                    end
               end
               else begin
                    state <= 0;
                    delay_counter <= 0;
               end
            end
            1: begin
                if (delay_counter < 2) begin
                    state <= 1;
                    delay_counter <= delay_counter + 1;
                end else begin
                    state <= 2;
                    data_output <= {$signed(9'b000000000), sigmoid_lut_data};
                end               
            end
            2: begin
                done <= 1;
                state <= 2;
            end
        endcase
    end
end

endmodule