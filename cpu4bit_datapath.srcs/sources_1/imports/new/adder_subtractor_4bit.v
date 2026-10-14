`timescale 1ns / 1ps

module adder_subtractor_4bit (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       sub,
    output wire [3:0] sum,
    output wire       c3,
    output wire       c4
);

    wire [3:0] b_selected;
    wire [4:0] carry;

    // ADD: b_selected = b and C0 = 0.
    // SUB: b_selected = ~b and C0 = 1, therefore a + ~b + 1.
    assign b_selected = b ^ {4{sub}};
    assign carry[0]   = sub;

    full_adder fa0 (
        .a   (a[0]),
        .b   (b_selected[0]),
        .cin (carry[0]),
        .sum (sum[0]),
        .cout(carry[1])
    );

    full_adder fa1 (
        .a   (a[1]),
        .b   (b_selected[1]),
        .cin (carry[1]),
        .sum (sum[1]),
        .cout(carry[2])
    );

    full_adder fa2 (
        .a   (a[2]),
        .b   (b_selected[2]),
        .cin (carry[2]),
        .sum (sum[2]),
        .cout(carry[3])
    );

    full_adder fa3 (
        .a   (a[3]),
        .b   (b_selected[3]),
        .cin (carry[3]),
        .sum (sum[3]),
        .cout(carry[4])
    );

    assign c3 = carry[3];
    assign c4 = carry[4];

endmodule