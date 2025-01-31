module conv2dValid_shift #
(
    parameter pixel = 4,
    parameter kernel = 3,
    parameter integer_width = 10,
    parameter fraction_width = 10,
    parameter stride = 1,
    parameter kernel_bit_width = 6
)
(
    input clk,
    input reset,
    input enableReadPixel,
    output wire [3:0] Input_Kernel_address,
    input wire [integer_width+fraction_width-1:0] Pixel_data,
    input wire [kernel_bit_width-1:0] Kernel_data,
    input wire [12:0] convOutput_Address,
    input wire convOutput_Enable,
    output wire [integer_width+fraction_width-1:0] convOutput_data,
    
    output reg done
);

wire signed [integer_width+fraction_width-1:0] input_data_S;
wire signed [kernel_bit_width-1:0] kernel_S;
reg signed [(2*integer_width+2*fraction_width)-1:0] Result_S = 0;
reg signed [integer_width+fraction_width-1:0] SaveResult =0;
wire signed [integer_width+fraction_width-1:0] Output;

reg signed [2*integer_width+2*fraction_width-1 : 0] Result_S_temp = 0;


reg Enable =0;
reg EnableSave = 0;

reg  [9:0] Address_Pixel = 0;
reg  [9:0] Total_Pixel =0;
reg  [3:0] Address_Kernel = 0;
reg  [4:0] Total_Kernel = 0;
reg  [12:0] Address_Output = 13'b111111111111;



BRAMPIXEL1 BRAMDataPixels(
    .clka(clk),
    .addra(Address_Pixel),
    .dina(Pixel_data),
    .douta(input_data_S),
    .ena(1'b1),
    .wea(enableReadPixel)
);

BRAMOUTPUT1 BRAMDataOutputs(
    .clka(clk),
    .addra(!done ? Address_Output : convOutput_Address),
    .dina(SaveResult),
    .douta(Output),
    .ena(1'b1),
    .wea(EnableSave)
);

localparam totalpixels = pixel*pixel;
localparam totalkernels = kernel*kernel;
localparam kernel_width = kernel;
localparam kernel_height = kernel;
localparam input_width = pixel;
localparam input_height = pixel;

localparam output_size = (pixel-kernel)/stride + 1;

reg [3:0] state = 4'b0;
localparam WRITE_INPUT_TO_BRAM=0, INIT_CALCULATION=1, PROCESS_ADDRESS=2, OFFSET_BRAM_READ=3, SAVE_TO_BRAM=4, LOOP_4_KERNEL_WIDTH=5, LOOP_3_KERNEL_HEIGHT=6, LOOP_2_OUTPUT_WIDTH_SIZE=7, LOOP_1_OUTPUT_HEIGHT_SIZE=8;

reg [31:0] i  = 0;
reg [31:0] j  = 0;
reg [31:0] ki = 0;  
reg [31:0] kj = 0;
reg [31:0] countOffset =0;

assign convOutput_data = Output;
assign Input_Kernel_address = Address_Kernel;
assign kernel_S = Kernel_data;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        Address_Pixel <= 0;
        Total_Pixel <= 0;
        Address_Kernel <= 0;
        Total_Kernel <= 0;
        Enable <= 0;

        i = 0;
        j = 0;
        ki = 0;
        kj = 0;
        countOffset = 0;
        done <= 0;
    end
    else begin
        case(state) 
            WRITE_INPUT_TO_BRAM : begin
                EnableSave <= 0;
                if (enableReadPixel == 1) begin
                    done <= 0;
                    Address_Pixel <= Address_Pixel + 1;
                    Total_Pixel <= Total_Pixel + 1;
                end
                else if (done == 0) begin
                    Address_Pixel <= Address_Pixel;
                    Total_Pixel <= Total_Pixel;
                end
                else begin
                    Address_Pixel <= 0;
                    Total_Pixel <= 0;
                end
                

                if ((Total_Pixel == (totalpixels)) && (done == 0)) begin
                    state <= INIT_CALCULATION;
                    Enable <= 1;
                end
                else begin
                    state <= WRITE_INPUT_TO_BRAM;
                end
            end

            INIT_CALCULATION : begin
                i = 0;
                j = 0;
                ki = 0;
                kj = 0;
                countOffset = 0;
                Result_S <= 0;
                state <= PROCESS_ADDRESS;
            end

            PROCESS_ADDRESS : begin
                countOffset <= 0;
                
                Address_Kernel <= ki * kernel + kj;
                Address_Pixel <= ((i*stride)+ki)*pixel + ((j*stride)+kj);
                
                state <= OFFSET_BRAM_READ;
            end

            OFFSET_BRAM_READ: begin
                countOffset <= countOffset+1;
                if (countOffset < 3) begin
                    state <= OFFSET_BRAM_READ;
                end else begin
                    if(kernel_S[kernel_bit_width-2] == 1) begin
                        if (input_data_S < 0) begin
                            Result_S_temp = ($signed({10'b1111111111, input_data_S, 10'b0000000000}) >>> $signed(kernel_S[kernel_bit_width-3:0]));
                        end else begin
                            Result_S_temp = ($signed({10'b0000000000, input_data_S, 10'b0000000000}) >>> $signed(kernel_S[kernel_bit_width-3:0]));
                        end
                    
                    end
                    else begin
                        if (input_data_S < 0) begin
                            Result_S_temp = ($signed({10'b1111111111, input_data_S, 10'b0000000000}) <<< $signed(kernel_S[kernel_bit_width-3:0]));
                        end else begin
                            Result_S_temp = ($signed({10'b0000000000, input_data_S, 10'b0000000000}) <<< $signed(kernel_S[kernel_bit_width-3:0]));
                        end
                    end

                    if(kernel_S[kernel_bit_width-1] == 1) begin
                        Result_S_temp = ~Result_S_temp + 1;
                    end
                    else begin
                        Result_S_temp = Result_S_temp;
                    end
                    Result_S <= Result_S + Result_S_temp;
                    state <= LOOP_4_KERNEL_WIDTH;                 
                end
            end

            SAVE_TO_BRAM : begin
                SaveResult = {Result_S[integer_width+2*fraction_width-1 -: integer_width], Result_S[2*fraction_width-1 -: fraction_width]};
                
                state <= LOOP_2_OUTPUT_WIDTH_SIZE;
                EnableSave = 1;
            end

            LOOP_4_KERNEL_WIDTH : begin
                EnableSave <= 0;
                kj <= kj + 1;
                if (kj < kernel_width -1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    kj <= 0;
                    state <= LOOP_3_KERNEL_HEIGHT;
                end
            end

            LOOP_3_KERNEL_HEIGHT : begin
                ki <= ki + 1;
                if (ki < kernel_height -1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    ki <= 0;
                    Address_Output <= i*output_size + j;
                    state <= SAVE_TO_BRAM;
                end
            end

            LOOP_2_OUTPUT_WIDTH_SIZE : begin
                j <= j + 1;
                Result_S <= 0;
                if (j < output_size -1) begin
                    state <= PROCESS_ADDRESS;
                    
                end
                else begin
                    j <= 0;
                    state <= LOOP_1_OUTPUT_HEIGHT_SIZE;
                end
            end

            LOOP_1_OUTPUT_HEIGHT_SIZE : begin
                i <= i + 1;
                if (i < output_size - 1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    i <= 0;
                    
                    state <= WRITE_INPUT_TO_BRAM;
                    done <= 1;
                    EnableSave <= 0;
                end
            end
            
        endcase
    end
end
endmodule
