module IODMA (
    input wire         aclk,
    input wire         aresetn,
    
    // *** AXIS slave port ***
    output reg         s_axis_tready,
    input wire [31:0]  s_axis_tdata,
    input wire         s_axis_tvalid,
    input wire         s_axis_tlast,
    
    // *** AXIS master port ***
    input wire        m_axis_tready,
    output reg [31:0] m_axis_tdata,
    output reg        m_axis_tvalid,
    output reg        m_axis_tlast
);

    //BRAM for Pixel, Kernel 1 and Kernel 2
    reg  [9:0]  BRAM2_Adress   = 0;    
    wire [19:0] BRAM2_Data_Out;
    
    BRAM2 DataInput(
        .clka(aclk),
        .addra(BRAM2_Adress),
        .dina(s_axis_tdata[19:0]),
        .douta(BRAM2_Data_Out),
        .wea(s_axis_tready)
    ); 
    
    // BRAM for storing the result
    reg  [9:0]   BRAM3_Adress = 0;               
    reg  [19:0]  BRAM3_Data_In;
    wire [19:0]  BRAM3_Data_Out; 
    reg          BRAM3_Wea   = 0;
    BRAM3 DataOutput(
        .clka(aclk),
        .addra(BRAM3_Adress),
        .dina(BRAM3_Data_In),
        .douta(BRAM3_Data_Out),
        .wea(BRAM3_Wea)
    );
    
    //Port map to VAutoEncoder
    reg  [19:0] Data_Input;
    reg         Done_M = 0 ;
    reg         LastData_M = 0;
    wire [19:0] Data_Out_S;
    wire LastData_S;
    wire Done_S;
        
    VAutoEncoder VAE(
    .clk(aclk),
    .data_In(Data_Input),
    .LasData_M(LastData_M),
    .Done_M(Done_M),
    .data_Out(Data_Out_S),
    .LastData_S(LastData_S),
    .Done_S(Done_S)
    );

    //Another Variable 
    reg [9:0] Total_Index   = 0;        

    reg     EnableProc  = 0; 
    reg     EnableSend  = 0;
    
    integer DelayProc = 0;
    integer DelaySend = 0; 

    always @(posedge aclk) begin

        if (aresetn == 0) begin 
            s_axis_tready   <= 1;
            m_axis_tvalid   <= 0;
            m_axis_tdata    <= 0;
            m_axis_tlast    <= 0;
            BRAM2_Adress    <= 0;
            Total_Index     <= 0;
            BRAM3_Adress    <= 0;
        end 

        else begin
        
        //Jupyter Ke BRAM
            if (s_axis_tvalid && s_axis_tready) begin
                BRAM2_Adress             <= BRAM2_Adress + 1;
                Total_Index             <= Total_Index + 1;
                
                if (s_axis_tlast) begin
                    s_axis_tready <= 0;
                    BRAM2_Adress   <= 0; 
                    EnableProc    <= 1; 
                    DelayProc     <= 0;
                end
            end
               
        //Bram Ke VAE
                   
            if (EnableProc == 1) begin
                case (DelayProc)
                    0: begin
                        BRAM2_Adress  <= BRAM2_Adress + 1; 
                        DelayProc    <= 1;
                    end
    
                    1: begin
                        BRAM2_Adress  <= BRAM2_Adress + 1;
                        DelayProc    <= 2;
                        Done_M    <= 1;
                    end
    
                    2: begin
                       Data_Input <= BRAM2_Data_Out;
                       BRAM2_Adress  <= BRAM2_Adress + 1;
                       
                       if (BRAM2_Adress == (Total_Index + 1)) begin
                           LastData_M <= 1;
                       end
                       
                       if (LastData_M == 1) begin
                           Done_M    <= 0;
                           LastData_M <= 0;
                           EnableProc <= 0;
                           BRAM3_Adress <=15;
                       end
          
                    end
                    
                endcase
            end
            
            if (Done_S == 1) begin 
                BRAM3_Wea <= 1;
                BRAM3_Adress <= BRAM3_Adress + 1;
                BRAM3_Data_In <= Data_Out_S;
                
                if (LastData_S == 1) begin
                    BRAM3_Wea <= 0;
                    EnableSend <= 1;
                    DelaySend <=0;
                    BRAM3_Adress <=0;
                end
                    
            end
            
            //Bram Ke Jupyter
            if (EnableSend == 1) begin
                case (DelaySend)
                    0: begin
                        BRAM3_Adress  <= BRAM3_Adress + 1; 
                        DelaySend    <= 1;
                    end
    
                    1: begin
                        BRAM3_Adress  <= BRAM3_Adress + 1;
                        DelaySend    <= 2;

                    end
    
                    2: begin
                        if (m_axis_tready) begin
                            
                            m_axis_tdata  <= {24'h000000, BRAM3_Data_Out};
                            BRAM3_Adress   <= BRAM3_Adress + 1;
    
                            if (BRAM3_Adress == (Total_Index + 20 )) begin
                                m_axis_tlast <= 1;
                            end
                            
                            if(m_axis_tlast == 0) begin
                                m_axis_tvalid <= 1;
                            end
                            
                            if (m_axis_tlast == 1) begin
                                m_axis_tvalid <= 0;
                                m_axis_tlast  <= 0;
                                EnableSend    <= 0;
                                BRAM2_Adress   <= 0;
                                s_axis_tready <= 1;
                                m_axis_tdata  <= 0;
                            end
                            
                        end
                    end    
                endcase
            end
        end
    end
endmodule