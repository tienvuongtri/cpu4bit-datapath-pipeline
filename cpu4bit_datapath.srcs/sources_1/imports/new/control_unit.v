`timescale 1ns / 1ps

module control_unit (
    input  wire [3:0] opcode,
    output wire sub,
    output wire arith,
    output wire d2,
    output wire d3,
    output wire d4,
    output wire d5,
    output wire is_shl,
    output wire is_shr,
    output wire is_div,
    output wire is_muldiv,
    output wire basic_valid
);

    assign sub         = (opcode == 4'b0001);
    assign arith       = (opcode[3:1] == 3'b000);
    assign d2          = (opcode == 4'b0010);
    assign d3          = (opcode == 4'b0011);
    assign d4          = (opcode == 4'b0100);
    assign d5          = (opcode == 4'b0101);
    assign is_shl      = (opcode == 4'b0110);
    assign is_shr      = (opcode == 4'b0111);
    assign is_div      = (opcode == 4'b1001);
    assign is_muldiv   = (opcode[3:1] == 3'b100);
    assign basic_valid = (opcode[3] == 1'b0);

endmodule