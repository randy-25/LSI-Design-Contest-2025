module maxpooling2d #
(
    parameter pixel = 4,
    parameter pool_width = 2,
    parameter pool_height = 2,
    parameter stride = 2,
    parameter integer_width = 10,
    parameter fraction_width = 10
)
(
    input clk,
    input reset,
    input enableReadPixel,
    input wire [integer_width+fraction_width-1:0] Pixel_data,

    input wire [8:0] maxpool_output_address,
    input wire maxpool_output_enable,
    output wire [integer_width+fraction_width-1:0] maxpool_output_data,
    output reg done
);

localparam integer input_data_width = integer_width + fraction_width;

wire signed [input_data_width-1:0] input_data_S;
reg signed [input_data_width-1:0] SaveResult = 0;
reg signed [input_data_width-1:0] Result_S = 0;
wire signed [input_data_width-1:0] Output;


reg Enable =0;
reg EnableSave = 0;

reg  [9:0] Address_Pixel = 0;
reg  [9:0] Total_Pixel =0;
reg  [9:0] Address_Output = 10'b1111111111;

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
    .addra(!done ? Address_Output : maxpool_output_address),
    .dina(SaveResult),
    .douta(Output),
    .ena(1'b1),
    .wea(EnableSave)
);

assign maxpool_output_data = Output;

localparam totalpixels = pixel*pixel;
localparam pool_size = pool_width*pool_height;
localparam output_size = (pixel)/stride;

reg [31:0] i=0;
reg [31:0] j=0;
reg [31:0] xidx=0;
reg [31:0] yidx=0;

reg [31:0] x_start=0;
reg [31:0] y_start=0;
reg [31:0] x_end=0;
reg [31:0] y_end=0;

reg [31:0] countOffset=0;
reg [31:0] count=0;

reg [4:0] state = 4'b0000;
localparam WRITE_INPUT_TO_BRAM=0, INIT_PROCESS=1, PROCESS_BOUNDARY=2, PROCESS_IDX=3, PROCESS_ADDRESS=4,OFFSET_BRAM_READ=5, SAVE_TO_BRAM=6, LOOP_4_Y=7, LOOP_3_X=8, LOOP_2_OUTPUT_HEIGHT=9, LOOP_1_OUTPUT_WIDTH=10;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        Address_Pixel <= 0;
        Total_Pixel <= 0;
        Address_Output <= 10'b1111111111;
        Enable <= 0;
        EnableSave <= 0;
        SaveResult <= 0;
        done <= 0;

        i <= 0;
        j <= 0;
        xidx <= 0;
        yidx <= 0;

        x_start <= 0;
        y_start <= 0;
        x_end <= 0;
        y_end <= 0;

        countOffset <= 0;
        count <= 0;
        state <= WRITE_INPUT_TO_BRAM;
    end
    else begin
        case (state)
            WRITE_INPUT_TO_BRAM : begin
                if (enableReadPixel == 1) begin
                    done <= 0;
                    Enable <= 0;
                    Address_Pixel <= Address_Pixel + 1;
                    Total_Pixel <= Total_Pixel + 1;
                end
                else if (done == 0) begin
                    Address_Pixel <= Address_Pixel;
                    Total_Pixel <= Total_Pixel;
                    Enable <= 0;
                end
                else begin
                    Address_Pixel <= 0;
                    Total_Pixel <= 0;
                    Enable <= 0;
                end

                if ((Total_Pixel == totalpixels) && (done == 0)) begin
                    state <= INIT_PROCESS;
                    Enable <= 1;
                end
                else begin
                    state <= WRITE_INPUT_TO_BRAM;
                end
            end

            INIT_PROCESS : begin
                i <= 0;
                j <= 0;

                countOffset <= 0;
                count <= 0;
                Result_S <= 0;
                state <= PROCESS_BOUNDARY;
            end
            PROCESS_BOUNDARY : begin
                x_start <= i * stride;
                y_start <= j * stride;
                x_end <= i * stride + pool_width;
                y_end <= j * stride + pool_height;
                state <= PROCESS_IDX;
            end
            PROCESS_IDX : begin
                yidx <= y_start;
                xidx <= x_start;
                state <= PROCESS_ADDRESS;
            end
            PROCESS_ADDRESS : begin
                countOffset <= 0;
                Address_Output <= i*output_size + j;
                Address_Pixel <= xidx*pixel + yidx;
                state <= OFFSET_BRAM_READ;
            end

            OFFSET_BRAM_READ : begin
                countOffset <= countOffset + 1;
                if(countOffset < 3) begin
                    state <= OFFSET_BRAM_READ;
                end
                else if (count == 0) begin
                    state <= LOOP_4_Y;
                    Result_S <= input_data_S;
                    count <= count + 1;
                end
                else if (count == pool_size -1) begin
                    state <= SAVE_TO_BRAM;
                    if (Result_S < input_data_S) begin
                        Result_S <= input_data_S;
                    end
                    else begin
                        Result_S <= Result_S;
                    end
                    
                end
                else begin
                    state <= LOOP_4_Y;
                    count <= count + 1;
                    if (Result_S < input_data_S) begin
                        Result_S <= input_data_S;
                    end
                    else begin
                        Result_S <= Result_S;
                    end
                end
            end
            SAVE_TO_BRAM : begin
                SaveResult <= Result_S;
                state <= LOOP_4_Y;
                EnableSave <= 1;
                count <= 0;
            end

            LOOP_4_Y : begin
                yidx <= yidx + 1;
                if (yidx < y_end - 1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    yidx <= y_start;
                    state <= LOOP_3_X;
                end
            end
            LOOP_3_X : begin
                xidx <= xidx + 1;
                if (xidx < x_end - 1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    xidx <= x_start;
                    state <= LOOP_2_OUTPUT_HEIGHT;
                end
            end
            LOOP_2_OUTPUT_HEIGHT: begin
                EnableSave <= 0;
                j <= j + 1;
                if (j < output_size - 1) begin
                    state <= PROCESS_BOUNDARY;
                end else begin
                    j <= 0;
                    state <= LOOP_1_OUTPUT_WIDTH;
                end
            end

            LOOP_1_OUTPUT_WIDTH: begin
                i <= i + 1;
                if (i < output_size - 1) begin
                    state <= PROCESS_BOUNDARY;
                end else begin
                    i <= 0;
                    state <= WRITE_INPUT_TO_BRAM;
                    done <= 1;
                end
            end
            default: begin
                state <= WRITE_INPUT_TO_BRAM;
            end
        endcase
    end
end

endmodule