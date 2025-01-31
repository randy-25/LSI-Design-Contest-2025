module VAutoEncoder(

    input wire clk,

    input wire [19:0] data_In,
    input wire LasData_M,
    input wire Done_M,
    
    output reg [19:0] data_Out,
    output reg LastData_S,
    output reg Done_S
    
    );

    localparam integer Pixel = 28 ;
    localparam integer Total_Pixel_Data = Pixel*Pixel;
    localparam integer epsilon = 2;

    // BRAM for storing the data Pixel
    reg  [9:0]  BRAM4_Adress = 0;
    wire [19:0] BRAM4_Data_Out;
    reg         BRAM4_Wea = 0;
    
    BRAM4 PIXELDATA (
        .clka(clk),
        .addra(BRAM4_Adress),
        .dina(data_In),
        .douta(BRAM4_Data_Out),
        .wea(BRAM4_Wea)
    );
    
    // BRAM for storing the result
    reg  [9:0]  BRAM7_Adress = 10'b1111111111;
    reg  [19:0] BRAM7_Data_In;
    wire [19:0] BRAM7_Data_Out;
    reg         BRAM7_Wea = 0;
    
    BRAM7 ResultVAE (
        .clka(clk),
        .addra(BRAM7_Adress),
        .dina(BRAM7_Data_In),
        .douta(BRAM7_Data_Out),
        .wea(BRAM7_Wea)
    );
    
    // BRAM for storing the data Eps
    reg  [1:0] BRAM22_Adress = 0;
    wire [11:0] BRAM22_Data_Out;
    reg  BRAM22_Wea = 0;

    wire [1:0] Epsilon_Output_Address;

    BRAM22 Epsilon (
        .clka(clk),
        .addra(BRAM22_Wea ? BRAM22_Adress : Epsilon_Output_Address),
        .dina(data_In),
        .douta(BRAM22_Data_Out),
        .wea(BRAM22_Wea)
    );

    //Encoder
    reg EnableSaveEncoder = 0;
    wire [6:0] Encoder_output_address;
    reg Encoder_output_enable = 0;
    wire [19:0] Encoder_output_data;
    wire Encoder_done;

    Encoder Encoders (
        .clk(clk),
        .Pixel_data(BRAM4_Data_Out),
        .EnableReadPixel(EnableSaveEncoder),
        .Encoder_output_address(Encoder_output_address),
        .Encoder_output_enable(Encoder_output_enable),
        .Encoder_output_data(Encoder_output_data),
        .done(Encoder_done)
    );

    //Latent Space
    wire [1:0] Latent_output_address;
    reg Latent_output_enable = 1;
    wire [19:0] Latent_output_data_mean;
    wire [19:0] Latent_output_data_logvar;
    wire done_mean;
    wire done_logvar;

   LatentSpace Latents (
       .clk(clk),
       .Encoder_output_address(Encoder_output_address),
       .EncoderData(Encoder_output_data),
       .EnableReadEncoder(Encoder_done),
       .Latent_output_address(Latent_output_address),
       .Latent_output_enable(Latent_output_enable),
       .Latent_output_data_mean(Latent_output_data_mean),
       .Latent_output_data_logvar(Latent_output_data_logvar),
       .donemean(done_mean),
       .donelogvar(done_logvar)
   );

   //Reparameterization

   reg EnableSaveParam = 0;
   wire doneLatent;
   assign doneLatent = done_mean & done_logvar;
   wire [1:0] RepAddress;
   wire [19:0] Reparameterization_Data_Out;
   wire doneRepara;

  Reparameterization Repara(
      .clk(clk),
      .reset(reset),
      .LatentSpace_Output_Address(Latent_output_address),
      .LatentSpace_LogVar(Latent_output_data_logvar),
      .LatentSpace_Mean(Latent_output_data_mean),
      .Epsilon_Address(Epsilon_Output_Address),
      .Epsilon(BRAM22_Data_Out),
      .EnableReadLatent(doneLatent),
      .Reparameterization_Output_Address(RepAddress),
      .Reparameterization_Data_Out(Reparameterization_Data_Out),
      .done(doneRepara)
  );

   //Decoder

   reg EnableSaveDecoder = 0;
   reg [12:0] Decoder_output_address = 0;
   reg Decoder_output_enable = 0;
   wire [19:0] Decoder_output_data;
   wire Decoder_done;

  Decoder Decoders(
      .clk(clk),
      .reset(reset),
      .Reparam_output_address(RepAddress),
      .Parametric_data(Reparameterization_Data_Out),
      .EnableReadParametric(doneRepara),
      .Decoder_output_address(Decoder_output_address),
      .Decoder_output_enable(Decoder_output_enable),
      .Decoder_output_data(Decoder_output_data),
      .Decoder_done(Decoder_done)
  );

    //Another variable
    reg [9:0] Total_Index = 0;
    
    reg BRAM4_WDone = 0;

    reg     EnableSendPixel = 0;    
    integer DelaySendPixel = 0;

    reg     DoneDecoder = 0;

    reg     EnableSaveResult = 0;
    integer DelaySaveResult  = 0;

    reg     EnableSend = 0;
    integer DelaySend  = 0;

    
    always @(posedge clk) begin
    
    
        if ((Done_M == 1) && (BRAM4_WDone == 0)) begin
            BRAM4_Wea    <= 1;
            BRAM4_WDone  <= 1;
            BRAM4_Adress <= 0; 
            Total_Index  <= 0;
        end
            
        if ((BRAM4_Wea == 1) && (BRAM4_Adress <= (Total_Pixel_Data-1))) begin
            
            if (BRAM4_Adress == (784-1)) begin
                BRAM4_Wea        <= 0;
                BRAM4_Adress     <= 10'b1111111111;
                BRAM22_Wea       <= 1;
                BRAM22_Adress     <= 0;
            end
            else begin
                BRAM4_Adress  <= BRAM4_Adress + 1;
                Total_Index   <= Total_Index + 1;
            end
        end
        
        if ((BRAM22_Wea == 1) && (BRAM22_Wea <= (epsilon-1))) begin

            
            if (BRAM22_Adress == (epsilon-1)) begin
                BRAM22_Wea       <= 0;
                BRAM22_Adress    <= 0;
                EnableSendPixel  <= 1;
                DelaySendPixel   <= 0;
            end
            else begin
                BRAM22_Adress  <= BRAM22_Adress + 1;
                Total_Index   <= Total_Index + 1;
            end
        end

        if (EnableSendPixel == 1) begin
            case (DelaySendPixel)
                0: begin
                    BRAM4_Adress  <= BRAM4_Adress + 1; 
                    DelaySendPixel    <= 1;
                end

                1: begin
                    BRAM4_Adress  <= BRAM4_Adress + 1;
                    DelaySendPixel       <= 2;
                    EnableSaveEncoder    <= 1;
                end

                2: begin
                    BRAM4_Adress  <= BRAM4_Adress + 1;
                    
                    if (BRAM4_Adress == (784 + 2)) begin
                        EnableSaveEncoder <= 0;
                        EnableSendPixel <= 0;
                    end
        
                end
          
            endcase
        end

       if((Decoder_done == 1) && (DoneDecoder == 0)) begin
           DoneDecoder      <= 1;
           EnableSaveResult <= 1;
           DelaySaveResult  <= 0;
           Decoder_output_address <= 0;
       end

       if (EnableSaveResult) begin
           case (DelaySaveResult)
               0: begin
                   Decoder_output_address  <= Decoder_output_address + 1;
                   DelaySaveResult    <= 1;
               end

               1: begin
                   Decoder_output_address  <= Decoder_output_address + 1;
                   DelaySaveResult    <= 2;
               end

               2: begin
                    
                   Decoder_output_address  <= Decoder_output_address + 1;

                   if (BRAM7_Adress == (Total_Pixel_Data+2)) begin
                       EnableSaveResult  <= 0;
                       EnableSend        <= 1;
                       DelaySend         <= 0;
                       BRAM7_Adress      <= 0;
                       BRAM7_Wea         <= 0;
                        
                   end

                   else begin
                       BRAM7_Wea     <= 1;
                       BRAM7_Adress  <= BRAM7_Adress + 1;
                       BRAM7_Data_In <= Decoder_output_data;
                   end
               end
           endcase
       end

        // Sending to IODM
        if (EnableSend == 1) begin
        
            case (DelaySend)
                0: begin
                    BRAM7_Adress  <= BRAM7_Adress + 1; 
                    DelaySend    <= 1;
                end

                1: begin
                    BRAM7_Adress  <= BRAM7_Adress + 1;
                    DelaySend    <= 2;

                end

                2: begin
                    
                    Done_S <=1;
                    BRAM7_Adress    <= BRAM7_Adress + 1;
                    data_Out       <= BRAM7_Data_Out;
                    
                    if (BRAM7_Adress == (Total_Index + 2)) begin
                        LastData_S <= 1;
                    end
                    
                    if (LastData_S == 1) begin
                        Done_S <= 0;
                        LastData_S <= 0;
                        EnableSend <= 0;
                        BRAM7_Adress <=0;
                    end   
        
                end
                
            endcase
        end
        
    end
    
endmodule
   