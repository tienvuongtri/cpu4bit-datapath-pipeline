`timescale 1ns / 1ps

module flag_register (
    input  wire clk,
    input  wire rst,
    input  wire zero_we,
    input  wire carry_we,
    input  wire zero_in,
    input  wire carry_in,
    output reg  zero_flag,
    output reg  carry_flag
);

    always @(posedge clk) begin
        if (rst) begin
            zero_flag  <= 1'b0;
            carry_flag <= 1'b0;
        end else begin
            if (zero_we)
                zero_flag <= zero_in;

            if (carry_we)
                carry_flag <= carry_in;
        end
    end

endmodule
