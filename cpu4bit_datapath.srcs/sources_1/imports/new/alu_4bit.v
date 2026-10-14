`timescale 1ns / 1ps

module alu_4bit (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [3:0] opcode,

    output wire [7:0] result,
    output wire       carry,
    output wire       zero,
    output wire       overflow,
    output wire       negative,
    output wire       busy,
    output wire       done,
    output wire       div_by_zero
);

    wire sub;
    wire arith;
    wire d2;
    wire d3;
    wire d4;
    wire d5;
    wire is_shl;
    wire is_shr;
    wire is_div;
    wire is_muldiv;
    wire basic_valid;

    wire [3:0] and_result;
    wire [3:0] or_result;
    wire [3:0] xor_result;
    wire [3:0] not_result;
    wire [3:0] shl_result;
    wire [3:0] shr_result;

    wire [3:0] md_add_a;
    wire [3:0] md_add_b;
    wire       md_add_sub;
    wire [7:0] md_result;

    wire [3:0] shared_adder_a;
    wire [3:0] shared_adder_b;
    wire       shared_adder_sub;
    wire [3:0] shared_sum;
    wire       shared_c3;
    wire       shared_c4;

    reg  [3:0] basic_result;
    wire       muldiv_active;

    control_unit control (
        .opcode      (opcode),
        .sub         (sub),
        .arith       (arith),
        .d2          (d2),
        .d3          (d3),
        .d4          (d4),
        .d5          (d5),
        .is_shl      (is_shl),
        .is_shr      (is_shr),
        .is_div      (is_div),
        .is_muldiv   (is_muldiv),
        .basic_valid (basic_valid)
    );

    logic_unit_4bit logic_unit (
        .a          (a),
        .b          (b),
        .and_result (and_result),
        .or_result  (or_result),
        .xor_result (xor_result),
        .not_result (not_result)
    );

    shifter_4bit shifter (
        .a(a),
        .shl_result (shl_result),
        .shr_result (shr_result)
    );

    // While MUL/DIV is busy, the sequential unit owns the shared adder.
    assign shared_adder_a   = busy ? md_add_a   : a;
    assign shared_adder_b   = busy ? md_add_b   : b;
    assign shared_adder_sub = busy ? md_add_sub : sub;

    adder_subtractor_4bit shared_adder (
        .a   (shared_adder_a),
        .b   (shared_adder_b),
        .sub (shared_adder_sub),
        .sum (shared_sum),
        .c3  (shared_c3),
        .c4  (shared_c4)
    );

    muldiv_unit muldiv (
        .clk           (clk),
        .rst           (rst),
        .start         (start & is_muldiv),
        .operation_div (is_div),
        .operand_a     (a),
        .operand_b     (b),
        .add_a         (md_add_a),
        .add_b         (md_add_b),
        .add_sub       (md_add_sub),
        .adder_sum     (shared_sum),
        .adder_carry   (shared_c4),
        .result        (md_result),
        .busy          (busy),
        .done          (done),
        .div_by_zero   (div_by_zero)
    );

    always @* begin
        case (opcode)
            4'b0000: basic_result = shared_sum;
            4'b0001: basic_result = shared_sum;
            4'b0010: basic_result = and_result;
            4'b0011: basic_result = or_result;
            4'b0100: basic_result = xor_result;
            4'b0101: basic_result = not_result;
            4'b0110: basic_result = shl_result;
            4'b0111: basic_result = shr_result;
            default: basic_result = 4'b0000;
        endcase
    end

    // Keep the sequential result visible while its operation is running even
    // if an external controller changes opcode prematurely.
    assign muldiv_active = busy | is_muldiv;
    assign result = muldiv_active ? md_result : {4'b0000, basic_result};

    flag_unit flags (
        .a              (a),
        .result_4bit    (basic_result),
        .result_8bit    (md_result),
        .c3             (shared_c3),
        .c4             (shared_c4),
        .arith          (arith),
        .is_shl         (is_shl),
        .is_shr         (is_shr),
        .basic_valid    (basic_valid),
        .muldiv_active  (muldiv_active),
        .carry          (carry),
        .zero           (zero),
        .overflow       (overflow),
        .negative       (negative)
    );

endmodule