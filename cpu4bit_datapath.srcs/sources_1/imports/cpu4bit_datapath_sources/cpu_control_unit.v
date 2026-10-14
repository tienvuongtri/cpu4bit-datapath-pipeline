`timescale 1ns / 1ps

module cpu_control_unit (
    input  wire [3:0] opcode,
    output reg  [3:0] alu_opcode,
    output reg        reg_we,
    output reg        mem_we,
    output reg        zero_we,
    output reg        carry_we,
    output reg  [1:0] wb_sel,
    output reg        is_jump,
    output reg        is_jz
);

    localparam [3:0] OP_ADD   = 4'b0000;
    localparam [3:0] OP_SUB   = 4'b0001;
    localparam [3:0] OP_AND   = 4'b0010;
    localparam [3:0] OP_OR    = 4'b0011;
    localparam [3:0] OP_XOR   = 4'b0100;
    localparam [3:0] OP_NOT   = 4'b0101;
    localparam [3:0] OP_LDI   = 4'b0110;
    localparam [3:0] OP_MOV   = 4'b0111;
    localparam [3:0] OP_LOAD  = 4'b1000;
    localparam [3:0] OP_STORE = 4'b1001;
    localparam [3:0] OP_JMP   = 4'b1010;
    localparam [3:0] OP_JZ    = 4'b1011;

    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_IMM = 2'b01;
    localparam [1:0] WB_RS  = 2'b10;
    localparam [1:0] WB_MEM = 2'b11;

    always @* begin
        // Safe defaults make reserved opcodes C-F behave as NOP.
        // They also prevent CPU LOAD/STORE from reaching the ALU as MUL/DIV.
        alu_opcode = OP_ADD;
        reg_we     = 1'b0;
        mem_we     = 1'b0;
        zero_we    = 1'b0;
        carry_we   = 1'b0;
        wb_sel     = WB_ALU;
        is_jump    = 1'b0;
        is_jz      = 1'b0;

        case (opcode)
            OP_ADD: begin
                alu_opcode = OP_ADD;
                reg_we     = 1'b1;
                zero_we    = 1'b1;
                carry_we   = 1'b1;
            end

            OP_SUB: begin
                alu_opcode = OP_SUB;
                reg_we     = 1'b1;
                zero_we    = 1'b1;
                carry_we   = 1'b1;
            end

            OP_AND: begin
                alu_opcode = OP_AND;
                reg_we     = 1'b1;
                zero_we    = 1'b1;
            end

            OP_OR: begin
                alu_opcode = OP_OR;
                reg_we     = 1'b1;
                zero_we    = 1'b1;
            end

            OP_XOR: begin
                alu_opcode = OP_XOR;
                reg_we     = 1'b1;
                zero_we    = 1'b1;
            end

            OP_NOT: begin
                alu_opcode = OP_NOT;
                reg_we     = 1'b1;
                zero_we    = 1'b1;
            end

            OP_LDI: begin
                reg_we = 1'b1;
                wb_sel = WB_IMM;
            end

            OP_MOV: begin
                reg_we = 1'b1;
                wb_sel = WB_RS;
            end

            OP_LOAD: begin
                reg_we = 1'b1;
                wb_sel = WB_MEM;
            end

            OP_STORE: begin
                mem_we = 1'b1;
            end

            OP_JMP: begin
                is_jump = 1'b1;
            end

            OP_JZ: begin
                is_jz = 1'b1;
            end

            default: begin
                // Reserved opcode: no state changes.
            end
        endcase
    end

endmodule
