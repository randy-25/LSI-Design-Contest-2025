module Encoder(
    input wire clk,

    input wire [19:0] Pixel_data,
    input wire EnableReadPixel,

    input  wire [6:0] Encoder_output_address,
    input  wire Encoder_output_enable,
    output wire [19:0] Encoder_output_data,
    output wire done
);

    localparam integer input_pixel_size = 28;
    localparam integer integer_width = 10;  
    localparam integer fraction_width = 10;

    localparam integer layer1_kernel_size = 3;
    localparam integer layer1_kernel_bit_width = 6;

    localparam integer Input_Total = input_pixel_size*input_pixel_size;
    
    localparam integer Layer1_Kernel_Total = layer1_kernel_size*layer1_kernel_size;

    
    // BRAM for storing the data Kernel1
    wire  [3:0] BRAM5_Adress;
    wire [5:0] BRAM5_Data_Out;
    reg        BRAM5_Wea = 0;

    BRAM5 KERNEL1DATA (
        .clka(clk),
        .addra(BRAM5_Adress),
        .dina(6'b000000),
        .douta(BRAM5_Data_Out),
        .wea(BRAM5_Wea)
    );

    // BRAM for storing the data Kernel2

    wire  [3:0] BRAM6_Adress;
    wire [5:0] BRAM6_Data_Out;
    reg        BRAM6_Wea = 0;

    BRAM6 KERNEL2DATA (
        .clka(clk),
        .addra(BRAM6_Adress),
        .dina(6'b000000),
        .douta(BRAM6_Data_Out),
        .wea(BRAM6_Wea)
    );

    // BRAM for storing the data Pixel
    reg  [9:0] BRAM8_Adress=0;
    wire [integer_width+fraction_width-1:0] BRAM8_Data_Out;
    reg  BRAM8_Wea = 0;
    reg  BRAM8_WDone = 0;

    BRAM8 Input_Pixel_BRAM(
        .clka(clk),
        .addra(BRAM8_Adress),
        .dina(Pixel_data),
        .douta(BRAM8_Data_Out),
        .wea(BRAM8_Wea)
    );
    
    //Convolution 
    localparam integer TotalOutputLayer2 = 169;

    reg reset             = 0;
    reg EnableSendPixel   = 0;  
    reg  [19:0] biasLayer1 = {20'b1111111111_1110100110}; //Bias for Layer 1
    reg  [12:0]                               layer1_output_address = 0;
    reg                                      layer1_output_enable = 0;
    wire [integer_width+fraction_width-1:0]  layer1_output_data;

    Encoder_Layer1_CNN #(
        .pixel(input_pixel_size),
        .kernel(layer1_kernel_size),
        .integer_width(10),
        .fraction_width(10),
        .stride(1),
        .kernel_bit_width(6)
    ) Layer1 (
        .clk(clk),
        .reset(reset),
        .enableReadPixel(EnableSendPixel),
        .Input_Kernel_address_1(BRAM5_Adress),
        .Input_Kernel_address_2(BRAM6_Adress),
        .Pixel_data(BRAM8_Data_Out),
        .Kernel_data_1(BRAM5_Data_Out),
        .Kernel_data_2(BRAM6_Data_Out),
        .bias(biasLayer1),
        .layer1_output_address(layer1_output_address),
        .layer1_output_enable(layer1_output_enable),
        .layer1_output_data(layer1_output_data),
        .done(donelayer1)
    );

    //MaxPooling
    localparam output_size = (input_pixel_size-layer1_kernel_size) + 1;
    reg EnableSendPool = 0;
    reg  [8:0] Layer2_Output_address  = 0;
    reg        Layer2_Output_enable = 0;
    wire [integer_width+fraction_width-1:0] Layer2_Output_data;
    reg  [19:0] MAXPOOLDATAIN;
    wire Layer2_done;
    maxpooling2d #(
        .pixel(output_size),
        .pool_width(2),
        .pool_height(2),
        .stride(2),
        .integer_width(10),
        .fraction_width(10)
    ) MaxPooling (
        .clk(clk),
        .reset(reset),
        .enableReadPixel(EnableSendPool),
        .Pixel_data(MAXPOOLDATAIN),
        .maxpool_output_address(Layer2_Output_address),
        .maxpool_output_enable(Layer2_Output_enable),
        .maxpool_output_data(Layer2_Output_data),
        .done(Layer2_done)
    );

    //Layer 3 Dense Layer
    localparam integer layer3_neuron = 100;
    localparam integer layer3_weight_rows = 169;
    localparam integer layer3_weight_cols = 100;
    localparam integer layer3_weight_bit_width = 6;

    localparam integer Layer3_Weight_Total = layer3_weight_rows*layer3_weight_cols;
    localparam TotalOutputLayer3 = layer3_neuron;

    reg Layer3_Input_enable = 0;
    reg Layer3_enableReadBias = 0;
    wire [layer3_weight_bit_width-1:0] Layer3_Weight_data_1;
    wire [layer3_weight_bit_width-1:0] Layer3_Weight_data_2;
    wire [integer_width+fraction_width-1:0] Layer3_bias;
    reg  [6:0] Layer3_Output_address = 0;
    reg  Layer3_Output_enable = 0;
    wire [integer_width+fraction_width-1:0] Layer3_Output_data;
    wire Layer3_done;

    wire [8:0] Layer3_Multiplier_1_Address;
    wire [14:0] Layer3_Multiplicand_1_Address;
    wire [8:0] Layer3_Multiplier_2_Address;
    wire [14:0] Layer3_Multiplicand_2_Address;
    wire [6:0] Layer3_Bias_Address;

    Encoder_Dense_Layer #(
        .neuron(layer3_neuron),
        .weight_rows(layer3_weight_rows),
        .weight_cols(layer3_weight_cols),
        .integer_width(integer_width),
        .fraction_width(fraction_width),
        .weight_bit_width(layer3_weight_bit_width)
    ) Layer3 (
        .clk(clk),
        .reset(reset),
        .enableOperation(Layer2_done),
        .enableReadNeuron(Layer3_Input_enable),
        .Input_Dense_Multiplicand_1_Address(Layer3_Multiplicand_1_Address),
        .Input_Dense_Multiplicand_2_Address(Layer3_Multiplicand_2_Address),
        .Input_Address_Bias(Layer3_Bias_Address),
        .Neuron_data(Layer2_Output_data),
        .Weight_data_1(Layer3_Weight_data_1),
        .Weight_data_2(Layer3_Weight_data_2),
        .bias(Layer3_bias),
        .dense_output_address(Layer3_Output_address),
        .dense_output_enable(Layer3_Output_enable),
        .dense_output_data(Layer3_Output_data),
        .done(Layer3_done)
    );

    // BRAM for storing the data Weight and Bias for Layer 3

    reg [14:0] Layer3_Address_Weight=0;
    BRAM9 Layer3_Weight1_BRAM(
        .clka(clk),
        .addra(Layer3_Multiplicand_1_Address),
        .dina(6'b000000),
        .douta(Layer3_Weight_data_1),
        .wea(1'b0)
    );

    BRAM10 Layer3_Weight2_BRAM(
        .clka(clk),
        .addra(Layer3_Multiplicand_2_Address),
        .dina(6'b000000),
        .douta(Layer3_Weight_data_2),
        .wea(1'b0)
    );


    BRAM11 Layer3_Bias_BRAM(
        .clka(clk),
        .addra(Layer3_Bias_Address),
        .dina(20'b00000000000000000000),
        .douta(Layer3_bias),
        .wea(1'b0)
    );

//    //Layer 4 Dense Layer
   localparam integer layer4_neuron = 50;
   localparam integer layer4_weight_rows = 100;
   localparam integer layer4_weight_cols = 50;
   localparam integer layer4_weight_bit_width = 6;

   localparam integer Layer4_Weight_Total = layer4_weight_rows*layer4_weight_cols;

   reg Layer4_Input_enable = 0;
   reg Layer4_enableReadWeight = 0;
   reg Layer4_enableReadBias = 0;
   wire [layer4_weight_bit_width-1:0] Layer4_Weight_data_1;
   wire [layer4_weight_bit_width-1:0] Layer4_Weight_data_2;
   wire [integer_width+fraction_width-1:0] Layer4_bias;

   reg Encoder_output_enables = 0;

   wire [14:0] Layer4_Multiplicand_1_Address;
    wire [14:0] Layer4_Multiplicand_2_Address;
    wire [6:0] Layer4_Bias_Address;

   Encoder_Dense_Layer #(
       .neuron(layer4_neuron),
       .weight_rows(layer4_weight_rows),
       .weight_cols(layer4_weight_cols),
       .integer_width(integer_width),
       .fraction_width(fraction_width),
       .weight_bit_width(layer4_weight_bit_width)
   ) Layer4 (
       .clk(clk),
       .reset(reset),
       .enableOperation(Layer3_done),
       .enableReadNeuron(Layer4_Input_enable),
       .Input_Dense_Multiplicand_1_Address(Layer4_Multiplicand_1_Address),
       .Input_Dense_Multiplicand_2_Address(Layer4_Multiplicand_2_Address),
       .Input_Address_Bias(Layer4_Bias_Address),
       .Neuron_data(Layer3_Output_data),
       .Weight_data_1(Layer4_Weight_data_1),
       .Weight_data_2(Layer4_Weight_data_2),
       .bias(Layer4_bias),
       .dense_output_address(Encoder_output_address),
       .dense_output_enable(Encoder_output_enable),
       .dense_output_data(Encoder_output_data),
       .done(done)
   );

   // BRAM for storing the data Weight and Bias for Layer 4
    
   BRAM12 Layer4_Weight1_BRAM(
       .clka(clk),
       .addra(Layer4_Multiplicand_1_Address),
       .dina(6'b000000),
       .douta(Layer4_Weight_data_1),
       .wea(1'b0)
   );

   BRAM13 Layer4_Weight2_BRAM(
       .clka(clk),
       .addra(Layer4_Multiplicand_2_Address),
       .dina(6'b000000),
       .douta(Layer4_Weight_data_2),
       .wea(1'b0)
   );

   BRAM14 Layer4_Bias_BRAM(
       .clka(clk),
       .addra(Layer4_Bias_Address),
       .dina(20'b00000000000000000000),
       .douta(Layer4_bias),
       .wea(1'b0)
   );

    reg [3:0] delayCounter = 0;
    reg [3:0] state = 0;
    localparam IDLE=0, WRITE_TO_LAYER3=1, DONE_LAYER_3=2, WRITE_TO_LAYER4=3, DONE_LAYER_4=4;

    reg        EnableConv = 0;
    integer    DelayConv  = 0;

    reg DoneConv = 0;

    reg     EnableMaxPool = 0;
    integer DelayMaxPool  = 0;

    reg Encoder_Done;
    
    always @(posedge clk) begin

        if ((EnableReadPixel == 1) && (BRAM8_WDone == 0)) begin
            BRAM8_Wea    <= 1;
            BRAM8_WDone  <= 1;
            BRAM8_Adress <= 0; 
        end
            
        if ((BRAM8_Wea == 1) && (BRAM8_Adress <= (Input_Total-1))) begin
            BRAM8_Adress  <= BRAM8_Adress + 1;
            
            if (BRAM8_Adress == (Input_Total-1)) begin
                BRAM8_Wea    <= 0;
                BRAM8_Adress <= 0;
                EnableConv   <= 1;
                DelayConv    <= 0;
            end
        end

        if (EnableConv == 1) begin
            case (DelayConv)
                0: begin
                    BRAM8_Adress  <= BRAM8_Adress + 1; 
                    DelayConv    <= 1;
                end

                1: begin
                    BRAM8_Adress  <= BRAM8_Adress + 1;
                    EnableSendPixel   <= 1;

                    DelayConv    <= 2;

                end

                2: begin
                
                    if (BRAM8_Adress  <= (Input_Total)) begin
                        BRAM8_Adress  <= BRAM8_Adress + 1;
                    end

                    if (BRAM8_Adress == (Input_Total+1)) begin
                        EnableSendPixel <= 0;
                    end

                    if (EnableSendPixel == 0)  begin
                        EnableConv   <= 0;
                        BRAM8_Adress <= 0;
                    end
        
                end
                
            endcase
        end

        if((donelayer1 == 1) && (DoneConv == 0)) begin
            DoneConv         <= 1;
            EnableMaxPool <= 1;
            DelayMaxPool  <= 0;
            layer1_output_address <= 0;
        end

        if (EnableMaxPool) begin
            case (DelayMaxPool)
                0: begin
                    layer1_output_address  <= layer1_output_address + 1; 
                    DelayMaxPool    <= 1;
                end

                1: begin
                    layer1_output_address  <= layer1_output_address + 1;
                    DelayMaxPool    <= 2;
                end

                2: begin

                    layer1_output_address  <= layer1_output_address + 1;
                    EnableSendPool <= 1;
                    MAXPOOLDATAIN <= layer1_output_data;
                    
                    if (layer1_output_address == ((output_size*output_size)+2)) begin
                        EnableMaxPool <= 0;
                        EnableSendPool <= 0;
                        
                    end
                end
            endcase
        end

        case (state)
            IDLE: begin
                if(Layer2_done) begin
                    state <= WRITE_TO_LAYER3;
                    Layer2_Output_address <= 0;
                    Layer2_Output_enable <= 1;
                    delayCounter <= 0;
                end
                else begin
                    state <= IDLE;
                    Layer2_Output_address <= 0;
                    Layer2_Output_enable <= 0;
                    Layer3_Output_address <= 0;
                    Layer3_Output_enable <= 0;

                    Layer3_Input_enable <= 0;
                    Layer4_Input_enable <= 0;
                end
            end

            WRITE_TO_LAYER3: begin
                if(Layer2_Output_address < TotalOutputLayer2 + 1) begin
                    Layer2_Output_address <= Layer2_Output_address + 1;
                    state <= WRITE_TO_LAYER3;
                    if(delayCounter < 1) begin
                        delayCounter <= delayCounter + 1;
                    end
                    else begin
                        Layer3_Input_enable <= 1;
                    end
                end
                else begin
                    Layer3_Input_enable <= 0;
                    if(Layer3_done) begin
                        state <= DONE_LAYER_3;
                    end
                    else begin
                        state <= WRITE_TO_LAYER3;
                    end
                end
            end

            DONE_LAYER_3: begin
                if(Layer3_done) begin
                    state <= WRITE_TO_LAYER4;
                    Layer3_Output_address <= 0;
                    Layer3_Output_enable <= 1;
                    delayCounter <= 0;
                end
                else begin
                    state <= DONE_LAYER_3;
                    Layer3_Output_address <= 0;
                    Layer3_Output_enable <= 0;
                    Layer4_Input_enable <= 0;
                end
            end

            WRITE_TO_LAYER4: begin
                if(Layer3_Output_address < TotalOutputLayer3 + 1) begin
                    Layer3_Output_address <= Layer3_Output_address + 1;
                    state <= WRITE_TO_LAYER4;
                    if(delayCounter < 1) begin
                        delayCounter <= delayCounter + 1;
                    end
                    else begin
                       Layer4_Input_enable <= 1;
                    end
                end
                else begin
                   Layer4_Input_enable <= 0;
                    if(done) begin
                        state <= DONE_LAYER_4;
                    end
                    else begin
                        state <= WRITE_TO_LAYER4;
                    end
                end
            end

            DONE_LAYER_4: begin
                state <= DONE_LAYER_4;
                
            end
        endcase
    end
endmodule
