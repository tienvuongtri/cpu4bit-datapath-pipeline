`timescale 1ns / 1ps

module flag_unit (
    input  wire [3:0] a,
    input  wire [3:0] result_4bit,
    input  wire [7:0] result_8bit,
    input  wire       c3,
    input  wire       c4,
    input  wire       arith,
    input  wire       is_shl,
    input  wire       is_shr,
    input  wire       basic_valid,
    input  wire       muldiv_active,
    output reg        carry,
    output reg        zero,
    output reg        overflow,
    output reg        negative
);

    always @* begin
        carry    = 1'b0;
        zero     = 1'b0;
        overflow = 1'b0;
        negative = 1'b0;

        if (muldiv_active) begin
            // MUL/DIV is unsigned in this design.
            zero = (result_8bit == 8'h00);
        end else if (basic_valid) begin
            zero     = (result_4bit == 4'b0000);
            negative = result_4bit[3];
            overflow = arith & (c3 ^ c4);

            if (arith)
                carry = c4;
            else if (is_shl)
                carry = a[3];
            else if (is_shr)
                carry = a[0];
        end
    end

endmodule