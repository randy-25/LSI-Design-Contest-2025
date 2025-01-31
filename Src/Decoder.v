module Decoder(
    input wire clk,
    input wire reset,

    output wire [1:0] Reparam_output_address,
    input wire [19:0] Parametric_data,
    input wire EnableReadParametric,

    input wire [12:0] Decoder_output_address,
    input wire Decoder_output_enable,
    output wire [19:0] Decoder_output_data,
    output wire Decoder_done
);

    localparam integer decoder_input_neuron = 2;
    localparam integer integer_width = 10;
    localparam integer fraction_width = 10;

    localparam integer layer1_neuron = 50; 
    localparam integer layer1_weight_rows = 2;
    localparam integer layer1_weight_cols = 50;
    localparam integer layer1_weight_bit_width = 6;

    localparam integer layer2_neuron = 100;
    localparam integer layer2_weight_rows = 50; 
    localparam integer layer2_weight_cols = 100; 

    localparam integer layer3_kernel_size = 3;
    localparam integer layer3_stride = 3;
    localparam integer layer3_kernel_bit_width = 6;

    localparam integer layer4_kernel_size = 3;
    localparam integer layer4_stride = 1;
    localparam integer layer4_kernel_bit_width = 6;

    localparam integer Total_Input_Layer1 = decoder_input_neuron;

    localparam integer Total_Weight_Layer1 = layer1_weight_rows*layer1_weight_cols;

    localparam integer Total_Bias_Layer1 = layer1_neuron;

    localparam integer Total_Input_layer2 = layer1_neuron;

    localparam integer Total_Weight_Layer2 = layer2_weight_rows*layer2_weight_cols;

    localparam integer Total_Bias_Layer2 = layer2_neuron;

    localparam integer Total_Pixel_Layer3 = layer2_neuron;

    localparam integer Total_Kernel_Layer3 = layer3_kernel_size*layer3_kernel_size;

    localparam integer Total_Input_Pixel_Layer4 = 30*30;

    localparam integer Total_Kernel_Layer4 = layer4_kernel_size*layer4_kernel_size;

    
    reg [1:0] layer1_Address_Neuron = 0;

    assign Reparam_output_address = layer1_Address_Neuron;

    wire signed [integer_width+fraction_width-1:0] layer1_input_data;

    assign layer1_input_data = Parametric_data;

    wire [14:0] layer1_Address_Weight_1;
    wire signed [layer1_weight_bit_width-1:0] layer1_Weight_data_1;

    BRAM28 Decoder_Layer1_Weight_1_BRAM(
        .clka(clk),
        .addra(layer1_Address_Weight_1),
        .dina(6'b000000),
        .douta(layer1_Weight_data_1),
        .wea(1'b0)
    );

    wire [14:0] layer1_Address_Weight_2;
    wire signed [layer1_weight_bit_width-1:0] layer1_Weight_data_2;

    BRAM29 Decoder_Layer1_Weight_2_BRAM(
        .clka(clk),
        .addra(layer1_Address_Weight_2),
        .dina(6'b000000),
        .douta(layer1_Weight_data_2),
        .wea(1'b0)
    );

    wire [6:0] layer1_Address_Bias;
    wire signed [integer_width+fraction_width-1:0] layer1_bias;
    BRAM30 Decoder_Layer1_Bias_BRAM(
        .clka(clk),
        .addra(layer1_Address_Bias),
        .dina(20'b00000000000000000000),
        .douta(layer1_bias),
        .wea(1'b0)
    );


    wire [14:0] layer2_Address_Weight_1;
    wire signed [layer1_weight_bit_width-1:0] layer2_Weight_data_1;

    BRAM31 Decoder_Layer2_Weight_1_BRAM(
        .clka(clk),
        .addra(layer2_Address_Weight_1),
        .dina(6'b000000),
        .douta(layer2_Weight_data_1),
        .wea(1'b0)
    );

    wire [14:0] layer2_Address_Weight_2;
    wire signed [layer1_weight_bit_width-1:0] layer2_Weight_data_2;
    BRAM32 Decoder_Layer2_Weight_2_BRAM(
        .clka(clk),
        .addra(layer2_Address_Weight_2),
        .dina(6'b000000),
        .douta(layer2_Weight_data_2),
        .wea(1'b0)
    );

    wire [6:0] layer2_Address_Bias;
    wire signed [integer_width+fraction_width-1:0] layer2_bias;
    BRAM33 Decoder_Layer2_Bias_BRAM(
        .clka(clk),
        .addra(layer2_Address_Bias),
        .dina(20'b00000000000000000000),
        .douta(layer2_bias),
        .wea(1'b0)
    );

    wire [3:0] layer3_Address_Kernel_1 ;
    wire signed [layer3_kernel_bit_width-1:0] layer3_Kernel_data_1;

    BRAM34 Decoder_Layer3_Kernel_1_BRAM(
        .clka(clk),
        .addra(layer3_Address_Kernel_1),
        .dina(6'b000000),
        .douta(layer3_Kernel_data_1),
        .wea(1'b0)
    );

    wire [3:0] layer3_Address_Kernel_2;
    wire signed [layer3_kernel_bit_width-1:0] layer3_Kernel_data_2;

    BRAM35 Decoder_Layer3_Kernel_2_BRAM(
        .clka(clk),
        .addra(layer3_Address_Kernel_2),
        .dina(6'b000000),
        .douta(layer3_Kernel_data_2),
        .wea(1'b0)
    );

    wire [3:0] layer4_Address_Kernel_1;
    wire signed [layer4_kernel_bit_width-1:0] layer4_Kernel_data_1;

    BRAM36 Decoder_Layer4_Kernel_1_BRAM(
        .clka(clk),
        .addra(layer4_Address_Kernel_1),
        .dina(6'b000000),
        .douta(layer4_Kernel_data_1),
        .wea(1'b0)
    );
    
    wire [3:0] layer4_Address_Kernel_2;
    wire signed [layer4_kernel_bit_width-1:0] layer4_Kernel_data_2;
    BRAM37 Decoder_Layer4_Kernel_2_BRAM(
        .clka(clk),
        .addra(layer4_Address_Kernel_2),
        .dina(6'b000000),
        .douta(layer4_Kernel_data_2),
        .wea(1'b0)
    );

    reg layer1_enableReadNeuron = 0;
    reg layer1_enableReadWeight = 0;
    reg layer1_enableReadBias = 0;
    reg [12:0] layer1_output_address = 0;
    wire signed [integer_width+fraction_width-1:0] layer1_output_data;
    wire layer1_done;

    Decoder_Dense_Layer #(
        .neuron(layer1_neuron),
        .weight_rows(layer1_weight_rows),
        .weight_cols(layer1_weight_cols),
        .integer_width(integer_width),
        .fraction_width(fraction_width),
        .weight_bit_width(layer1_weight_bit_width)
    ) Decoder_Layer1 (
        .clk(clk),
        .reset(reset),
        .enableOperation(EnableReadParametric),
        .enableReadNeuron(layer1_enableReadNeuron),
        .Input_Dense_Multiplicand_1_Address(layer1_Address_Weight_1),
        .Input_Dense_Multiplicand_2_Address(layer1_Address_Weight_2),
        .Input_Address_Bias(layer1_Address_Bias),
        .Neuron_data(layer1_input_data),
        .Weight_data_1(layer1_Weight_data_1),
        .Weight_data_2(layer1_Weight_data_2),
        .bias(layer1_bias),
        .dense_output_address(layer1_output_address),
        .dense_output_enable(1'b1),
        .dense_output_data(layer1_output_data),
        .done(layer1_done)
    );

    reg layer2_enableReadNeuron = 0;
    reg [12:0] layer2_output_address = 0;
    wire signed [integer_width+fraction_width-1:0] layer2_output_data;
    wire layer2_done;

    Decoder_Dense_Layer #(
        .neuron(layer2_neuron),
        .weight_rows(layer2_weight_rows),
        .weight_cols(layer2_weight_cols),
        .integer_width(integer_width),
        .fraction_width(fraction_width),
        .weight_bit_width(layer1_weight_bit_width)
    ) Decoder_Layer2 (
        .clk(clk),
        .reset(reset),
        .enableOperation(layer1_done),
        .enableReadNeuron(layer2_enableReadNeuron),
        .Input_Dense_Multiplicand_1_Address(layer2_Address_Weight_1),
        .Input_Dense_Multiplicand_2_Address(layer2_Address_Weight_2),
        .Input_Address_Bias(layer2_Address_Bias),
        .Neuron_data(layer1_output_data),
        .Weight_data_1(layer2_Weight_data_1),
        .Weight_data_2(layer2_Weight_data_2),
        .bias(layer2_bias),
        .dense_output_address(layer2_output_address),
        .dense_output_enable(1'b1),
        .dense_output_data(layer2_output_data),
        .done(layer2_done)
    );

    reg layer3_enableReadPixel = 0;
    reg [integer_width+fraction_width-1:0] layer3_bias = 0;
    reg [12:0] layer3_output_address = 0;
    wire signed [integer_width+fraction_width-1:0] layer3_output_data;
    wire layer3_done;

    Decoder_Layer3_Conv2dTranspose #(
        .pixel(10),
        .kernel(layer3_kernel_size),
        .integer_width(integer_width),
        .fraction_width(fraction_width),
        .stride(layer3_stride),
        .kernel_bit_width(layer3_kernel_bit_width)
    ) Decoder_Layer3 (
        .clk(clk),
        .reset(reset),
        .enableReadPixel(layer3_enableReadPixel),
        .Input_Kernel_1_address(layer3_Address_Kernel_1),
        .Input_Kernel_2_address(layer3_Address_Kernel_2),
        .Pixel_data(layer2_output_data),
        .Kernel_data_1(layer3_Kernel_data_1),
        .Kernel_data_2(layer3_Kernel_data_2),
        .bias(layer3_bias),
        .layer1_output_address(layer3_output_address),
        .layer1_output_enable(1'b1),
        .layer1_output_data(layer3_output_data),
        .done(layer3_done)
    );

    reg layer4_enableReadPixel = 0;
    reg layer4_enableReadKernel = 0;
    reg [integer_width+fraction_width-1:0] layer4_bias = 0;
    reg [12:0] layer4_output_address = 0;
    wire signed [integer_width+fraction_width-1:0] layer4_output_data;
    wire layer4_done;

    Decoder_Layer4_CNN #(
        .pixel(30),
        .kernel(layer4_kernel_size),
        .integer_width(integer_width),
        .fraction_width(fraction_width),
        .stride(layer4_stride),
        .kernel_bit_width(layer4_kernel_bit_width)
    ) Decoder_Layer4 (
        .clk(clk),
        .reset(reset),
        .enableReadPixel(layer4_enableReadPixel),
        .Input_Kernel_1_address(layer4_Address_Kernel_1),
        .Input_Kernel_2_address(layer4_Address_Kernel_2),
        .Pixel_data(layer3_output_data),
        .Kernel_data_1(layer4_Kernel_data_1),
        .Kernel_data_2(layer4_Kernel_data_2),
        .bias(layer4_bias),
        .layer1_output_address(Decoder_output_address),
        .layer1_output_enable(1'b1),
        .layer1_output_data(Decoder_output_data),
        .done(Decoder_done)
    );


always @(posedge clk) begin
    if (EnableReadParametric == 1) begin

        if (layer1_Address_Neuron <= Total_Input_Layer1) begin
            layer1_Address_Neuron <= layer1_Address_Neuron + 1;
        end

        if (layer1_Address_Neuron == 1) begin
            layer1_enableReadNeuron <= 1;
        end

        if (layer1_Address_Neuron == (Total_Input_Layer1 + 1)) begin
            layer1_enableReadNeuron <= 0;
        end
    end

    if (layer1_done) begin
        if (layer1_output_address <= Total_Input_layer2) begin
            layer1_output_address <= layer1_output_address + 1;
        end

        if (layer1_output_address == 1) begin
            layer2_enableReadNeuron <= 1;
        end

        if (layer1_output_address == (Total_Input_layer2 + 1)) begin
            layer2_enableReadNeuron <= 0;
        end
    end

    if (layer2_done) begin
        if (layer2_output_address <= Total_Pixel_Layer3) begin
            layer2_output_address <= layer2_output_address + 1;
        end

        if (layer2_output_address == 1) begin
            layer3_enableReadPixel <= 1;
        end

        if (layer2_output_address == (Total_Pixel_Layer3 + 1)) begin
            layer3_enableReadPixel <= 0;
        end
 
        layer3_bias = 20'b00000000110011110001;
    end

    if (layer3_done) begin
        if (layer3_output_address <= Total_Input_Pixel_Layer4) begin
            layer3_output_address <= layer3_output_address + 1;
        end

        if (layer3_output_address == 1) begin
            layer4_enableReadPixel <= 1;
        end

        if (layer3_output_address == (Total_Input_Pixel_Layer4 + 1)) begin
            layer4_enableReadPixel <= 0;
        end
        layer4_bias = 20'b0000000001_1111011101;
    end

end

endmodule
