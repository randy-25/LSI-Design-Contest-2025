module TB;

    // Size of the pixel and kernel
    localparam integer Pixel  = 28;
    localparam integer Total_Data = (Pixel*Pixel)+2;
    
    // BRAM for storing the data
    reg  clk;
    reg  [9:0] Adress_Data  = 10'b1111111111;
    wire [19:0]  Data_BRAM1;
    
    BRAM1 Jupyter(
        .clka(clk),
        .addra(Adress_Data),
        .dina(20'b00000000000000000000),
        .douta(Data_BRAM1),
        .wea(1'b0)
    );

    // DMA module

    reg  Reset = 1 ;

    wire s_axis_tready;
    reg  s_axis_tvalid;
    reg  s_axis_tlast = 0;
    
    reg m_axis_tready = 0;
    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    wire        m_axis_tlast;
    
    IODMA PROC(
    .aclk         (clk),
    .aresetn      (Reset),
    .s_axis_tready(s_axis_tready),
    .s_axis_tdata (Data_BRAM1),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast (s_axis_tlast),
    .m_axis_tready(1'b1),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast (m_axis_tlast)
    );

    // Testbench

    reg EnableSendPixel = 0 ;
    
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // Clock period 10 ns
    end
    
    initial begin
        #10 begin
            s_axis_tvalid = 1;
            Reset = 0;
        end
    end
    
    always @(posedge clk) begin

        if (s_axis_tvalid == 1) begin

            
            if ((Adress_Data <= (Total_Data)) || (Adress_Data == 1023)) begin
                Adress_Data <= Adress_Data + 1;
            end
            
            if (Adress_Data == 1) begin
                EnableSendPixel <= 1;
                Reset           <= 1;
            end

            if (Adress_Data == (Total_Data)) begin
                s_axis_tlast <= 1;
            end
            
            if (Adress_Data == (Total_Data+1)) begin
                EnableSendPixel <= 0;
                s_axis_tlast    <= 0;
                s_axis_tvalid   <= 0;
            end
        end
          
        
    end
    
endmodule
