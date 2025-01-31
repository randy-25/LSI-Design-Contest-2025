module LatentSpace(
    input clk,

    output wire [14:0] Encoder_output_address,
    input wire [19:0] EncoderData,
    input wire EnableReadEncoder,

    input wire [1:0] Latent_output_address,
    input wire Latent_output_enable,
    output wire [19:0] Latent_output_data_mean,
    output wire [19:0] Latent_output_data_logvar,
    output wire donemean,
    output wire donelogvar

);
    localparam integer integer_width = 10;
    localparam integer fraction_width = 10;

    localparam integer LatentSpace_neuron = 2;
    localparam integer LatentSpace_weight_rows = 50;
    localparam integer LatentSpace_weight_cols = 2;
    localparam integer LatentSpace_weight_bit_width = 6;

    localparam integer LatentSpace_Weight_Total = LatentSpace_weight_rows * LatentSpace_weight_cols;

    reg reset =0;

    reg LatentSpace_enableReadNeuron;
    reg LatentSpace_enableReadWeight;
    reg LatentSpace_enableReadBias;

    wire [LatentSpace_weight_bit_width-1:0] LatentSpace_Weight_data_1_mean;
    wire [LatentSpace_weight_bit_width-1:0] LatentSpace_Weight_data_2_mean;

    wire [LatentSpace_weight_bit_width-1:0] LatentSpace_Weight_data_1_logvar;
    wire [LatentSpace_weight_bit_width-1:0] LatentSpace_Weight_data_2_logvar;

    reg [5:0] LatentSpace_Address_Input = 0;
    wire signed [integer_width+fraction_width-1:0] LatentSpace_Neuron_data;

    assign Encoder_output_address = LatentSpace_Address_Input;
    assign LatentSpace_Neuron_data = EncoderData;

    wire [6:0] LatentSpace_weight_1_address_mean;
    wire [6:0] LatentSpace_weight_2_address_mean;
    BRAM16 LatentSpace_Weight_Mean_1_BRAM(
        .clka(clk),
        .addra(LatentSpace_weight_1_address_mean),
        .dina(6'b000000),
        .douta(LatentSpace_Weight_data_1_mean),
        .wea(1'b0)
    );

    BRAM17_0 LatentSpace_Weight_Mean_2_BRAM(
        .clka(clk),
        .addra(LatentSpace_weight_2_address_mean),
        .dina(6'b000000),
        .douta(LatentSpace_Weight_data_2_mean),
        .wea(1'b0)
    );

    wire [6:0] LatentSpace_weight_1_address_logvar;
    wire [6:0] LatentSpace_weight_2_address_logvar;

    BRAM19 LatentSpace_Weight_Logvar_1_BRAM(
        .clka(clk),
        .addra(LatentSpace_weight_1_address_logvar),
        .dina(6'b000000),
        .douta(LatentSpace_Weight_data_1_logvar),
        .wea(1'b0)
    );

    BRAM20 LatentSpace_Weight_Logvar_2_BRAM(
        .clka(clk),
        .addra(LatentSpace_weight_2_address_logvar),
        .dina(6'b000000),
        .douta(LatentSpace_Weight_data_2_logvar),
        .wea(1'b0)
    );

    reg [integer_width+fraction_width-1:0] bias_mean_1;
    reg [integer_width+fraction_width-1:0] bias_mean_2;

    reg [integer_width+fraction_width-1:0] bias_logvar_1;
    reg [integer_width+fraction_width-1:0] bias_logvar_2;

    Latent_Space_Dense #(
        .neuron(LatentSpace_neuron),
        .weight_rows(LatentSpace_weight_rows),
        .weight_cols(LatentSpace_weight_cols),
        .integer_width(integer_width),
        .fraction_width(fraction_width),
        .weight_bit_width(LatentSpace_weight_bit_width)
    ) LatentSpace_Dense_Mean (
        .clk(clk),
        .reset(reset),
        .enableOperation(EnableReadEncoder),
        .enableReadNeuron(LatentSpace_enableReadNeuron),
        .Input_Dense_Multiplicand_1_Address(LatentSpace_weight_1_address_mean),
        .Input_Dense_Multiplicand_2_Address(LatentSpace_weight_2_address_mean),
        .Neuron_data(LatentSpace_Neuron_data),
        .Weight_data_1(LatentSpace_Weight_data_1_mean),
        .Weight_data_2(LatentSpace_Weight_data_2_mean),
        .bias_1(bias_mean_1),
        .bias_2(bias_mean_2),
        .dense_output_address(Latent_output_address),
        .dense_output_enable(Latent_output_enable),
        .dense_output_data(Latent_output_data_mean),
        .done(donemean)
    );

    Latent_Space_Dense #(
        .neuron(LatentSpace_neuron),
        .weight_rows(LatentSpace_weight_rows),
        .weight_cols(LatentSpace_weight_cols),
        .integer_width(integer_width),
        .fraction_width(fraction_width),
        .weight_bit_width(LatentSpace_weight_bit_width)
    ) LatentSpace_Dense_Logvar (
        .clk(clk),
        .reset(reset),
        .enableOperation(EnableReadEncoder),
        .enableReadNeuron(LatentSpace_enableReadNeuron),
        .Input_Dense_Multiplicand_1_Address(LatentSpace_weight_1_address_logvar),
        .Input_Dense_Multiplicand_2_Address(LatentSpace_weight_2_address_logvar),
        .Neuron_data(LatentSpace_Neuron_data),
        .Weight_data_1(LatentSpace_Weight_data_1_logvar),
        .Weight_data_2(LatentSpace_Weight_data_2_logvar),
        .bias_1(bias_logvar_1),
        .bias_2(bias_logvar_2),
        .dense_output_address(Latent_output_address),
        .dense_output_enable(Latent_output_enable),
        .dense_output_data(Latent_output_data_logvar),
        .done(donelogvar)
    );

    always @(posedge clk) begin
        if (EnableReadEncoder) begin
            bias_mean_1 <= $signed(20'b00000000000010010101);
            bias_mean_2 <= $signed(20'b00000000000000101011);

            bias_logvar_1 <= $signed(20'b11111111001101110011);
            bias_logvar_2 <= $signed(20'b11111111001010000110);
            if(LatentSpace_Address_Input <= LatentSpace_weight_rows) begin
                LatentSpace_Address_Input <= LatentSpace_Address_Input + 1;
            end

            if (LatentSpace_Address_Input == 1) begin
                LatentSpace_enableReadNeuron <= 1;
            end

            if (LatentSpace_Address_Input == (LatentSpace_weight_rows + 1)) begin
                LatentSpace_enableReadNeuron <= 0;
            end
        end

    end

endmodule