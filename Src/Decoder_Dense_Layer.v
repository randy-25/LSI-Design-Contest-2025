module Decoder_Dense_Layer #
(
    parameter neuron = 100,
    parameter weight_rows = 169,
    parameter weight_cols = 100,
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
    output wire [6:0] Input_Address_Bias,
    input wire [integer_width+fraction_width-1:0] Neuron_data,
    input wire [weight_bit_width-1:0] Weight_data_1,
    input wire [weight_bit_width-1:0] Weight_data_2,
    input wire [integer_width+fraction_width-1:0] bias,
    input wire [6:0] dense_output_address,
    input wire dense_output_enable,
    output wire [integer_width+fraction_width-1:0] dense_output_data,
    
    output reg done
);

reg [9:0] matrixmult_output_address = 0;
reg matrixmult_output_enable = 0;
wire [integer_width+fraction_width-1:0] matrixmult_output_data_1;
wire [integer_width+fraction_width-1:0] matrixmult_output_data_2;

wire DoneMatrixMult_1;
wire DoneMatrixMult_2;
localparam bias_size = neuron;

reg [9:0] Total_Bias = 0;

wire signed [integer_width+fraction_width-1:0] bias_S;
assign bias_S = bias;

reg [6:0] Address_Bias = 0;

assign Input_Address_Bias = Address_Bias;

wire [14:0] Mult1_Address_Multiplicand;

wire [14:0] Mult2_Address_Multiplicand;

assign Input_Dense_Multiplicand_1_Address = Mult1_Address_Multiplicand;
assign Input_Dense_Multiplicand_2_Address = Mult2_Address_Multiplicand;

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
    .Input_Address_Multiplicand(Mult1_Address_Multiplicand),
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
    .Input_Address_Multiplicand(Mult2_Address_Multiplicand),
    .multiplier(Neuron_data),
    .multiplicand(Weight_data_2),
    .matrixmult_output_address(matrixmult_output_address),
    .matrixmult_output_enable(matrixmult_output_enable),
    .matrixmult_output_data(matrixmult_output_data_2),
    .done(DoneMatrixMult_2)
);

reg [integer_width+fraction_width-1:0] sum;

reg reluEnable = 0;
reg reluReset = 1;
wire doneRelu;
wire [integer_width+fraction_width-1:0] reluOutput;

relu #(
    .integer_width(integer_width),
    .fraction_width(fraction_width)
) relu_comp (
    .clk(clk),
    .reset(reluReset),
    .enable(reluEnable),
    .input_data(sum),
    .output_data(reluOutput),
    .done(doneRelu)
);

reg writeToBramEnable = 0;

BRAMDenseOutputLayer BRAMDenseOutputLayer (
    .clka(clk),
    .addra(!done ? matrixmult_output_address : dense_output_address),
    .dina(reluOutput),
    .douta(dense_output_data),
    .wea(writeToBramEnable)
);



reg [2:0] state = 0;
localparam IDLE=0, DELAY_READ_MULT = 1, ACTIVATE=2, DONEACTIVATE=3, INCREMENT_ADDRESS=4, DONE_DENSE_LAYER=5;

reg [3:0] delayCounter = 0;


always @(posedge clk or posedge reset) begin
    if (reset) begin
        done <= 0;
        matrixmult_output_address <= 0;
        matrixmult_output_enable <= 0;
        reluEnable <= 0;
        reluReset <= 1;
        writeToBramEnable <= 0;
        sum <= 0;
        delayCounter <= 0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (!enableOperation) begin
                    state <= IDLE;
                end
                else begin
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
            end

            DELAY_READ_MULT: begin
                if (delayCounter < 3) begin
                    state <= DELAY_READ_MULT;
                    delayCounter <= delayCounter + 1;
                end
                else begin
                    state <= ACTIVATE;
                    delayCounter <= 0;                
                end
            end

            ACTIVATE: begin
                sum <= ($signed({matrixmult_output_data_1})) + ($signed({matrixmult_output_data_2})) + ($signed({bias_S}));
                reluEnable <= 1;
                reluReset <= 0;
                state <= DONEACTIVATE;  
            end

            DONEACTIVATE : begin
                if (doneRelu) begin
                    state <= INCREMENT_ADDRESS;
                    writeToBramEnable <= 1;
                end
                else begin
                    state <= DONEACTIVATE;
                    reluEnable <= 1;
                    reluReset <= 0;
                end
            end

            INCREMENT_ADDRESS: begin
                reluReset <= 1;
                reluEnable <= 0;
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