`timescale 1ns / 1ps

module program_counter_4bit (
    input  wire       clk,
    input  wire       rst,
    input  wire       pc_we,
    input  wire [3:0] pc_next,
    output reg  [3:0] pc
);

    always @(posedge clk) begin
        if (rst)
            pc <= 4'b0000;
        else if (pc_we)
            pc <= pc_next;
    end

endmodule
