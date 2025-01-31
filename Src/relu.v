module relu#
    (
        parameter integer integer_width=20,
        parameter integer fraction_width=20   
    )
    (
        input clk,
        input reset,
        input enable,
        input [(integer_width+fraction_width)-1 : 0] input_data,
        output reg [(integer_width+fraction_width) -1 : 0] output_data,
        output reg done
    );

    reg done_relu = 0;

    integer i;
    integer j;

    always @(posedge clk) begin
        if (reset == 1) begin
            done = 0;
            output_data = 0;
        end
        else if (enable == 1) begin           
            if ($signed(input_data) < 0) begin
                output_data = 0;
            end
            else begin
                output_data = input_data;
            end
            done = 1;
        end
        else begin
            output_data = 0;
            done = 0;
        end
    end
endmodule