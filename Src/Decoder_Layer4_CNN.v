module Decoder_Layer4_CNN #
(
    parameter pixel = 10,
    parameter kernel = 3,
    parameter integer_width = 10,
    parameter fraction_width = 10,
    parameter stride = 3,
    parameter kernel_bit_width = 6
)
(
    input clk,
    input reset,
    input enableReadPixel,
    output wire [3:0] Input_Kernel_1_address,
    output wire [3:0] Input_Kernel_2_address,
    input wire [integer_width+fraction_width-1:0] Pixel_data,
    input wire [kernel_bit_width-1:0] Kernel_data_1,
    input wire [kernel_bit_width-1:0] Kernel_data_2,

    input [integer_width+fraction_width-1:0] bias,

    input wire [12:0] layer1_output_address,
    input wire layer1_output_enable,
    output wire [integer_width+fraction_width-1:0] layer1_output_data,

    output reg done
);

localparam output_size = (pixel-kernel)/stride + 1;
localparam totalOutput = output_size*output_size;

reg [12:0] convOutput_Address = 0;
reg convOutput_Enable = 0;
wire [integer_width+fraction_width-1:0] convOutput_data_1;
wire [integer_width+fraction_width-1:0] convOutput_data_2;

wire DoneConv_1;

conv2dValid_shift #(
    .pixel(pixel),
    .kernel(kernel),
    .integer_width(integer_width),
    .fraction_width(fraction_width),
    .stride(stride),
    .kernel_bit_width(kernel_bit_width)
) convValid1 (
    .clk(clk),
    .reset(reset),
    .enableReadPixel(enableReadPixel),
    .Input_Kernel_address(Input_Kernel_1_address),
    .Pixel_data(Pixel_data),
    .Kernel_data(Kernel_data_1),
    .convOutput_Address(convOutput_Address),
    .convOutput_Enable(convOutput_Enable),
    .convOutput_data(convOutput_data_1),
    .done(DoneConv_1)
);

wire DoneConv_2;

conv2dValid_shift #(
    .pixel(pixel),
    .kernel(kernel),
    .integer_width(integer_width),
    .fraction_width(fraction_width),
    .stride(stride),
    .kernel_bit_width(kernel_bit_width)
) convValid2 (
    .clk(clk),
    .reset(reset),
    .enableReadPixel(enableReadPixel),
    .Input_Kernel_address(Input_Kernel_2_address),
    .Pixel_data(Pixel_data),
    .Kernel_data(Kernel_data_2),
    .convOutput_Address(convOutput_Address),
    .convOutput_Enable(convOutput_Enable),
    .convOutput_data(convOutput_data_2),
    .done(DoneConv_2)
);

reg [integer_width+fraction_width-1:0] sum;
reg [integer_width+fraction_width - 1: 0] sigmoid_input;

reg sigmoidEnable = 0;
reg sigmoidReset = 1;
wire doneSigmoid;
wire [integer_width+fraction_width-1:0] sigmoidOutput;

sigmoid #(
    .input_integer_width(integer_width),
    .input_fraction_width(fraction_width),
    .output_integer_width(integer_width),
    .output_fraction_width(fraction_width)
) sigmoid_comp (
    .clk(clk),
    .reset(sigmoidReset),
    .enable(sigmoidEnable),
    .data_input(sigmoid_input),
    .data_output(sigmoidOutput),
    .done(doneSigmoid)
);

reg writeToBramEnable = 0;

BRAMOutputLayer4 BRAMLayer4Output (
    .clka(clk),
    .addra(!done ? convOutput_Address : layer1_output_address),
    .dina(sigmoidOutput),
    .douta(layer1_output_data),
    .ena(!done ? 1'b1 : layer1_output_enable),
    .wea(writeToBramEnable)
);


reg [2:0] state = 0;
localparam IDLE=0, DELAY_READ_CONV = 1, ACTIVATE=2, DONEACTIVATE=3, INCREMENT_ADDRESS=4, DONE_LAYER_1=5;



reg [3:0] delayCounter = 0;



always @(posedge clk or posedge reset) begin
    if (reset) begin
        done <= 0;
        convOutput_Address <= 0;
        convOutput_Enable <= 0;
        sigmoidEnable <= 0;
        sigmoidReset <= 1;
        writeToBramEnable <= 0;
        sum <= 0;
        delayCounter <= 0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (DoneConv_1 && DoneConv_2) begin
                    done <= 0;
                    sum <= 0;
                    state <= DELAY_READ_CONV;
                    convOutput_Address <= 0;
                    convOutput_Enable <= 1;
                end
                else begin
                    state <= IDLE;
                    sum <= 0;
                    convOutput_Address <= 0;
                    convOutput_Enable <= 0;
                end
            end

            DELAY_READ_CONV: begin
                if (delayCounter < 3) begin
                    state <= DELAY_READ_CONV;
                    delayCounter <= delayCounter + 1;
                end
                else begin
                    state <= ACTIVATE;
                    delayCounter <= 0;                
                end
            end

            ACTIVATE: begin
                sum = convOutput_data_1 + convOutput_data_2 + bias;
                sigmoid_input = sum;
                sigmoidEnable <= 1;
                sigmoidReset <= 0;
                state <= DONEACTIVATE;  
            end

            DONEACTIVATE : begin
                if (doneSigmoid) begin
                    state <= INCREMENT_ADDRESS;
                    writeToBramEnable <= 1;
                end
                else begin
                    state <= DONEACTIVATE;
                    sigmoidEnable <= 1;
                    sigmoidReset <= 0;
                end
            end

            INCREMENT_ADDRESS: begin
                sigmoidReset <= 1;
                sigmoidEnable <= 0;
                writeToBramEnable <= 0;
                if (convOutput_Address < totalOutput -1) begin
                    convOutput_Address <= convOutput_Address + 1;
                    
                    state <= DELAY_READ_CONV;
                end
                else begin
                    state <= DONE_LAYER_1;
                end
            end

            DONE_LAYER_1: begin
                done <= 1;
                state <= DONE_LAYER_1;
            end
        endcase
    end
end

endmodule