
module Reparameterization(
        input clk,
        input reset,
        output wire [1:0] LatentSpace_Output_Address,
        input [19:0] LatentSpace_LogVar,
        input [19:0] LatentSpace_Mean,

        output wire [1:0] Epsilon_Address,
        input [11:0] Epsilon,

        input EnableReadLatent,
        input wire [1:0] Reparameterization_Output_Address,
        output wire [19:0] Reparameterization_Data_Out,
        output reg done
);

    localparam integer integer_width = 10;
    localparam integer fraction_width = 10;

    reg [1:0] LatentSpace_Address = 0;

    assign LatentSpace_Output_Address = LatentSpace_Address;

    reg [1:0] BRAM25_Address = 0;

    assign Epsilon_Address = BRAM25_Address;

    reg [1:0] BRAM26_Address = 2'b11;
    reg [19:0] BRAM26_Data_In;
    wire [19:0] BRAM26_Data_Out;
    assign Reparameterization_Data_Out = BRAM26_Data_Out;
    reg BRAM26_Wea = 0;

    BRAM26 ResultData(
        .clka(clk),
        .addra(!done ? BRAM26_Address : Reparameterization_Output_Address),
        .dina(BRAM26_Data_In),
        .douta(BRAM26_Data_Out),
        .wea(BRAM26_Wea)
    );

    
    reg resetexp = 0;
    reg EnableExp = 0;
    reg [19:0] exponent_input = 0;
    wire [19:0] Exp_Result1;
    wire doneexp1;

    exponential #(
        .input_integer_width(10),
        .input_fraction_width(10),
        .output_integer_width(10),
        .output_fraction_width(10)
    ) exp1(
        .clk(clk),
        .reset(resetexp),
        .enable(EnableExp),
        .data_input(exponent_input),
        .data_output(Exp_Result1),
        .done(doneexp1)
    );

    reg [19:0] data_output = 0; 

    reg [39:0] MultEps = 0;

    integer DelayPoc = 0;

    integer TotalDataLatent = 2;

    reg BRAM_Wdone = 0;

    reg [2:0] delayCounter = 0;

    always @(posedge clk) begin
        if (reset) begin
            LatentSpace_Address <= 0;
            BRAM26_Address <= 2'b11;
            BRAM26_Wea <= 0;
            BRAM26_Data_In <= 0;
            done <= 0;
            resetexp <= 0;
            EnableExp <= 0;
            exponent_input <= 0;
            DelayPoc <= 0;
        end else begin
                case (DelayPoc)
                    0: begin
                        if (EnableReadLatent) begin 
                            LatentSpace_Address <= 0;
                            BRAM25_Address <= 0;
                            BRAM26_Address <= 0;
                            BRAM26_Data_In <= 0;
                            delayCounter <= 0;
                            done <= 0;
                            DelayPoc <= 1;
                        end
                        else begin
                            DelayPoc <= 0;
                        end
                    end
                    1: begin
                        if (delayCounter < 3) begin
                            delayCounter <= delayCounter + 1;
                            DelayPoc <= 1;
                        end
                        else begin
                            delayCounter <= 0;
                            DelayPoc <= 2;
                        end
                    end
                    2: begin
                        exponent_input <= {LatentSpace_LogVar[integer_width+fraction_width-1], LatentSpace_LogVar} >> 1;
                        resetexp <= 0;
                        EnableExp <= 1;
                        DelayPoc <= 3;
                    end

                    3: begin
                        if(doneexp1) begin
                           MultEps <= $signed({Epsilon[11], Epsilon[11], Epsilon[11], Epsilon[11], Epsilon[11], Epsilon[11], Epsilon[11], Epsilon[11],Epsilon})*Exp_Result1;
                            DelayPoc <= 4;
                            resetexp <= 1;
                            EnableExp <= 0;
                        end
                        else begin
                            DelayPoc <= 3;
                        end
                    end

                    4: begin
                       BRAM26_Data_In <= LatentSpace_Mean + MultEps[30:10];
                        DelayPoc <= 5;
                        BRAM26_Wea <= 1;
                    end
                    5: begin
                        BRAM26_Wea <= 0;
                        if (BRAM26_Address < (TotalDataLatent-1)) begin
                            DelayPoc <= 1;
                            BRAM26_Address <= BRAM26_Address + 1;
                            BRAM25_Address <= BRAM25_Address + 1;
                            LatentSpace_Address <= LatentSpace_Address + 1;
                        end
                        else begin
                            DelayPoc <= 6;
                        end
                    end
                    6: begin
                        done <= 1;
                    end
                endcase
            end
        end
endmodule
