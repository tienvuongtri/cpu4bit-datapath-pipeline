`timescale 1ns / 1ps

// IF/ID pipeline register. It keeps the fetched instruction together with
// its address and a valid bit so bubbles are explicit in simulation.
module instruction_register_12bit (
    input  wire        clk,
    input  wire        rst,
    input  wire        ir_load,
    input  wire        flush,
    input  wire [11:0] instruction_in,
    input  wire [3:0]  pc_in,
    output reg  [11:0] instruction_out,
    output reg  [3:0]  pc_out,
    output reg         valid_out
);

    always @(posedge clk) begin
        if (rst || flush) begin
            instruction_out <= 12'hC00;
            pc_out          <= 4'b0000;
            valid_out       <= 1'b0;
        end else if (ir_load) begin
            instruction_out <= instruction_in;
            pc_out          <= pc_in;
            valid_out       <= 1'b1;
        end
    end

endmodule
