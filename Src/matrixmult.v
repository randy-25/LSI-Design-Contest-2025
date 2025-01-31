module matrixmult #
(
    parameter multiplier_rows = 1,
    parameter multiplier_cols = 4,
    parameter multiplicand_rows = 3,
    parameter multiplicand_cols = 3,
    parameter multiplicand_bit_width = 6,
    parameter integer_width = 10,
    parameter fraction_width = 10   
)
(
    input clk,
    input reset,
    input enableReadMultiplier,
    output wire [14:0] Input_Address_Multiplicand,
    input wire [(integer_width + fraction_width) - 1 : 0] multiplier,
    input wire [multiplicand_bit_width - 1 : 0] multiplicand,

    input wire [9:0] matrixmult_output_address,
    input wire matrixmult_output_enable,
    output wire [(integer_width + fraction_width) - 1 : 0] matrixmult_output_data,

    output reg done
);

wire signed [(integer_width + fraction_width) - 1 : 0] multiplier_data_S;
wire signed [multiplicand_bit_width - 1 : 0] multiplicand_data_S;
reg signed [(2 * integer_width + 2 * fraction_width) - 1 : 0] Result_S = 0;
reg signed [2*integer_width+2*fraction_width-1 : 0] Result_S_temp = 0;
reg signed [(integer_width + fraction_width) - 1 : 0] SaveResult = 0;
wire signed [(integer_width + fraction_width) - 1 : 0] Output;


reg  [9:0] Address_Multiplier = 0;
reg  [9:0] Total_Multiplier =0;

reg  [9:0] Address_Output = 10'b1111111111;

reg Enable =1;
reg EnableSave = 0;

BRAMMULTIPLIER BRAMMultiplierData(
    .clka(clk),
    .addra(Address_Multiplier),
    .dina(multiplier),
    .douta(multiplier_data_S),
    .wea(enableReadMultiplier)
);

reg  [14:0] Address_Multiplicand = 0;
reg  [14:0] Total_Multiplicand = 0;


BRAMMATRIXMULTOUTPUT BRAMatrixMultDataOutputs(
    .clka(clk),
    .addra(!done ? Address_Output : matrixmult_output_address),
    .dina(SaveResult),
    .douta(Output),
    .wea(EnableSave)
);

assign Input_Address_Multiplicand = Address_Multiplicand;
assign multiplicand_data_S = multiplicand;
assign matrixmult_output_data = Output;

localparam multiplier_size = multiplier_rows * multiplier_cols;
localparam multiplicand_size = multiplicand_rows * multiplicand_cols;
localparam output_size = multiplier_rows * multiplicand_cols;

reg [31:0] i = 0; 
reg [31:0] j = 0;
reg [31:0] k = 0;
reg [31:0] countOffset=0;

reg [3:0] state=4'b0;
localparam WRITE_INPUT_TO_BRAM = 0, INIT_CALCULATION = 1, PROCESS_ADDRESS=2, OFFSET_BRAM_READ=3, SAVE_TO_BRAM = 4, MULTIPLIER_COLS_1 = 5, MULTIPLICAND_COLS_1 = 6, MULTIPLIER_ROWS_1 = 7, WRITE_OUTPUT = 8, FINISH=9;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        Address_Multiplier <= 0;
        Total_Multiplier <= 0;
        Address_Multiplicand <= 0;
        Total_Multiplicand <= 0;
        Enable <= 0;

        i = 0;
        j = 0;
        k = 0;
        countOffset = 0;
        done <= 0;
    end
    else begin
        case(state) 
            WRITE_INPUT_TO_BRAM : begin
                if (enableReadMultiplier == 1) begin
                    done <= 0;
                    Address_Multiplier <= Address_Multiplier + 1;
                    Total_Multiplier <= Total_Multiplier + 1;
                end
                else if (done == 0) begin
                    Address_Multiplier <= Address_Multiplier;
                    Total_Multiplier <= Total_Multiplier;
                end
                else begin
                    Address_Multiplier <= 0;
                    Total_Multiplier <= 0;
                end

                if ((Total_Multiplier == (multiplier_size)) && (done == 0)) begin
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
                k = 0;
                countOffset = 0;
                Result_S <= 0;
                state <= PROCESS_ADDRESS;
            end

            PROCESS_ADDRESS : begin
                countOffset <= 0;
                
                Address_Multiplicand <= k*multiplicand_cols + j;
                Address_Multiplier <= i * multiplier_cols + k;
                state <= OFFSET_BRAM_READ;
            end

            OFFSET_BRAM_READ: begin
                countOffset <= countOffset+1;
                if (countOffset < 3) begin
                    state <= OFFSET_BRAM_READ;
                end else begin
                    if(multiplicand_data_S[multiplicand_bit_width-2] == 1) begin
                        if (multiplier_data_S < 0) begin
                            Result_S_temp = ($signed({10'b1111111111, multiplier_data_S, 10'b0000000000}) >>> $signed(multiplicand_data_S[multiplicand_bit_width-3:0]));
                        end else begin
                            Result_S_temp = ($signed({10'b0000000000, multiplier_data_S, 10'b0000000000}) >>> $signed(multiplicand_data_S[multiplicand_bit_width-3:0]));
                        end
                    end
                    else begin
                        if (multiplier_data_S < 0) begin
                            Result_S_temp = ($signed({10'b1111111111, multiplier_data_S, 10'b0000000000}) <<< $signed(multiplicand_data_S[multiplicand_bit_width-3:0]));
                        end else begin
                            Result_S_temp = ($signed({10'b0000000000, multiplier_data_S, 10'b0000000000}) <<< $signed(multiplicand_data_S[multiplicand_bit_width-3:0]));
                        end
                    end

                    if(multiplicand_data_S[multiplicand_bit_width-1] == 1) begin
                        Result_S_temp = ~Result_S_temp + 1;
                    end
                    else begin
                        Result_S_temp = Result_S_temp;
                    end
                    Result_S <= Result_S + Result_S_temp;
                    state <= MULTIPLIER_COLS_1;                   
                end
            end

            SAVE_TO_BRAM : begin
                 SaveResult = {Result_S[integer_width+2*fraction_width-1 -: integer_width], Result_S[2*fraction_width-1 -: fraction_width]};
                state <= MULTIPLICAND_COLS_1;
                EnableSave <= 1;
            end

            MULTIPLIER_COLS_1 : begin
                EnableSave <= 0;
                k <= k + 1;
                if (k < multiplier_cols -1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    k <= 0;
                    Address_Output <= ((i)*multiplicand_cols + (j));
                    state <= SAVE_TO_BRAM;
                end
            end

            MULTIPLICAND_COLS_1 : begin
                j <= j + 1;
                Result_S <= 0;
                if (j < multiplicand_cols -1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    j <= 0;
                    state <= MULTIPLIER_ROWS_1;
                end
            end

            MULTIPLIER_ROWS_1 : begin
                i <= i + 1;
                if (i < multiplier_rows - 1) begin
                    state <= PROCESS_ADDRESS;
                end
                else begin
                    i <= 0;
                    state <= WRITE_INPUT_TO_BRAM;
                    EnableSave <= 0;
                    done <= 1;
                end
            end            
        endcase
    end
end

endmodule