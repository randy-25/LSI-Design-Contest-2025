module Latent_Space_Dense #
(
    parameter neuron = 2,
    parameter weight_rows = 50,
    parameter weight_cols = 2,
    parameter integer_width = 10,
    parameter fraction_width = 10,
    parameter weight_bit_width = 6
)
(
    input clk,
    input reset,
    input enableOperation,
    input enableReadNeuron,
    output wire [14:0] Input_Dense_Multiplicand_1_Address,
    output wire [14:0] Input_Dense_Multiplicand_2_Address,
    input wire [integer_width+fraction_width-1:0] Neuron_data,
    input wire [weight_bit_width-1:0] Weight_data_1,
    input wire [weight_bit_width-1:0] Weight_data_2,
    input wire [integer_width+fraction_width-1:0] bias_1,
    input wire [integer_width+fraction_width-1:0] bias_2,
    input wire [1:0] dense_output_address,
    input wire dense_output_enable,
    output wire [integer_width+fraction_width-1:0] dense_output_data,
    
    output reg done
);

reg [9:0] matrixmult_output_address = 0;
reg matrixmult_output_enable = 0;
wire [integer_width+fraction_width-1:0] matrixmult_output_data_1;
wire [integer_width+fraction_width-1:0] matrixmult_output_data_2;

wire signed [integer_width+fraction_width-1:0] bias_S [1:0];

assign bias_S[0] = bias_1;
assign bias_S[1] = bias_2;

wire DoneMatrixMult_1;
wire DoneMatrixMult_2;
localparam bias_size = neuron;

reg Address_Bias = 0;

matrixmult #(
    .multiplier_rows(1),
    .multiplier_cols(weight_rows),
    .multiplicand_rows(weight_rows),
    .multiplicand_cols(weight_cols),
    .multiplicand_bit_width(weight_bit_width),
    .integer_width(integer_width),
    .fraction_width(fraction_width)
) MatrixMult1 (
    .clk(clk),
    .reset(reset),
    .enableReadMultiplier(enableReadNeuron),
    .Input_Address_Multiplicand(Input_Dense_Multiplicand_1_Address),
    .multiplier(Neuron_data),
    .multiplicand(Weight_data_1),
    .matrixmult_output_address(matrixmult_output_address),
    .matrixmult_output_enable(matrixmult_output_enable),
    .matrixmult_output_data(matrixmult_output_data_1),
    .done(DoneMatrixMult_1)
);

matrixmult #(
    .multiplier_rows(1),
    .multiplier_cols(weight_rows),
    .multiplicand_rows(weight_rows),
    .multiplicand_cols(weight_cols),
    .multiplicand_bit_width(weight_bit_width),
    .integer_width(integer_width),
    .fraction_width(fraction_width)
) MatrixMult2 (
    .clk(clk),
    .reset(reset),
    .enableReadMultiplier(enableReadNeuron),
    .Input_Address_Multiplicand(Input_Dense_Multiplicand_2_Address),
    .multiplier(Neuron_data),
    .multiplicand(Weight_data_2),
    .matrixmult_output_address(matrixmult_output_address),
    .matrixmult_output_enable(matrixmult_output_enable),
    .matrixmult_output_data(matrixmult_output_data_2),
    .done(DoneMatrixMult_2)
);

reg [integer_width+fraction_width-1:0] sum;

reg writeToBramEnable = 0;

BRAMDenseOutputLayer BRAMDenseOutputLayer (
    .clka(clk),
    .addra(!done ? matrixmult_output_address : dense_output_address),
    .dina(sum),
    .douta(dense_output_data),
    .wea(writeToBramEnable)
);



reg [2:0] state = 0;
localparam WRITE_BIAS_TO_REG=0, IDLE=1, DELAY_READ_MULT = 2, WRITE_OUTPUT_BRAM=3, INCREMENT_ADDRESS=4, DONE_DENSE_LAYER=5;

reg [3:0] delayCounter = 0;


always @(posedge clk or posedge reset) begin
    if (reset) begin
        done <= 0;
        matrixmult_output_address <= 0;
        matrixmult_output_enable <= 0;
        writeToBramEnable <= 0;
        sum <= 0;
        delayCounter <= 0;
        state <= IDLE;
    end else begin
        case (state)
            WRITE_BIAS_TO_REG: begin
                if (enableOperation == 1) begin
                    state <= IDLE;
                end
                else begin
                    state <= WRITE_BIAS_TO_REG;
                end
            end
            IDLE: begin
                if (DoneMatrixMult_1 && DoneMatrixMult_2) begin
                    done <= 0;
                    sum <= 0;
                    state <= DELAY_READ_MULT;
                    matrixmult_output_address <= 0;
                    Address_Bias <= 0;
                    matrixmult_output_enable <= 1;
                end
                else begin
                    state <= IDLE;
                    sum <= 0;
                    matrixmult_output_address <= 0;
                    Address_Bias = 0;
                    matrixmult_output_enable <= 0;
                end
            end

            DELAY_READ_MULT: begin
                if (delayCounter < 3) begin
                    state <= DELAY_READ_MULT;
                    delayCounter <= delayCounter + 1;
                end
                else begin
                    state <= WRITE_OUTPUT_BRAM;
                    delayCounter <= 0;                
                end
            end

            WRITE_OUTPUT_BRAM : begin
                sum <= ($signed({matrixmult_output_data_1})) + ($signed({matrixmult_output_data_2})) + ($signed({bias_S[Address_Bias]}));
                state <= INCREMENT_ADDRESS;
                writeToBramEnable <= 1;
            end

            INCREMENT_ADDRESS: begin
                writeToBramEnable <= 0;
                if (matrixmult_output_address < neuron -1) begin
                    matrixmult_output_address <= matrixmult_output_address + 1;
                    Address_Bias = Address_Bias + 1;
                    
                    state <= DELAY_READ_MULT;
                end
                else begin
                    state <= DONE_DENSE_LAYER;
                end
            end

            DONE_DENSE_LAYER: begin
                done <= 1;
                state <= DONE_DENSE_LAYER;
            end
        endcase
    end
end

endmodule