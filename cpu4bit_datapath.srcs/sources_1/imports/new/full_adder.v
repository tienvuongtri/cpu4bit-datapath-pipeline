`timescale 1ns / 1ps

module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    wire propagate;
    wire generate_carry;

    assign propagate     = a ^ b;
    assign generate_carry = a & b;
    assign sum           = propagate ^ cin;
    assign cout          = generate_carry | (propagate & cin);

endmodule

