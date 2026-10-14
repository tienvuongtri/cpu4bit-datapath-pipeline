`timescale 1ns / 1ps

module shifter_4bit (
    input  wire [3:0] a,
    output wire [3:0] shl_result,
    output wire [3:0] shr_result
);

    assign shl_result = {a[2:0], 1'b0};
    assign shr_result = {1'b0, a[3:1]};

endmodule

