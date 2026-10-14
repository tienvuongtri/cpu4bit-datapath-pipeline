`timescale 1ns / 1ps

module cpu_4bit_top #(
    parameter PROGRAM_FILE = "program.mem"
) (
    input  wire        clk,
    input  wire        rst,
    output wire [3:0]  pc_out,
    output wire [11:0] instruction_out,
    output wire        state_out,
    output wire [3:0]  alu_result_out,
    output wire [3:0]  writeback_data_out,
    output wire        zero_flag_out,
    output wire        carry_flag_out,
    output wire [3:0]  id_pc_out,
    output wire [3:0]  ex_pc_out,
    output wire [11:0] id_instruction_out,
    output wire        if_id_valid_out,
    output wire        id_ex_valid_out,
    output wire        flush_out
);

    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_IMM = 2'b01;
    localparam [1:0] WB_RS  = 2'b10;
    localparam [1:0] WB_MEM = 2'b11;

    // -----------------------------------------------------------------
    // Stage 1: IF - fetch one instruction every clock.
    // -----------------------------------------------------------------
    wire [3:0]  pc;
    wire [3:0]  pc_plus_one;
    wire [3:0]  pc_next;
    wire [11:0] fetched_instruction;
    wire [3:0]  ex_immediate;

    wire        branch_taken;
    wire        pipeline_flush;

    assign pc_plus_one = pc + 4'b0001;
    assign pc_next     = branch_taken ? ex_immediate : pc_plus_one;
    assign pipeline_flush = branch_taken;

    program_counter_4bit program_counter (
        .clk     (clk),
        .rst     (rst),
        .pc_we   (1'b1),
        .pc_next (pc_next),
        .pc      (pc)
    );

    instruction_memory_16x12 #(
        .PROGRAM_FILE(PROGRAM_FILE)
    ) instruction_memory (
        .address     (pc),
        .instruction (fetched_instruction)
    );

    // IF/ID pipeline register. A taken branch converts the younger
    // instruction into a bubble at the same edge that redirects the PC.
    wire [11:0] id_instruction;
    wire [3:0]  id_pc;
    wire        id_valid;

    instruction_register_12bit instruction_register (
        .clk             (clk),
        .rst             (rst),
        .ir_load         (1'b1),
        .flush           (pipeline_flush),
        .instruction_in  (fetched_instruction),
        .pc_in           (pc),
        .instruction_out (id_instruction),
        .pc_out          (id_pc),
        .valid_out       (id_valid)
    );

    // -----------------------------------------------------------------
    // Stage 2: ID - decode the instruction held in IF/ID.
    // -----------------------------------------------------------------
    wire [3:0] id_opcode;
    wire [1:0] id_rd;
    wire [1:0] id_rs;
    wire [3:0] id_immediate;

    wire [3:0] id_alu_opcode;
    wire       id_reg_we;
    wire       id_mem_we;
    wire       id_zero_we;
    wire       id_carry_we;
    wire [1:0] id_wb_sel;
    wire       id_is_jump;
    wire       id_is_jz;

    assign id_opcode    = id_instruction[11:8];
    assign id_rd        = id_instruction[7:6];
    assign id_rs        = id_instruction[5:4];
    assign id_immediate = id_instruction[3:0];

    cpu_control_unit cpu_control (
        .opcode     (id_opcode),
        .alu_opcode (id_alu_opcode),
        .reg_we     (id_reg_we),
        .mem_we     (id_mem_we),
        .zero_we    (id_zero_we),
        .carry_we   (id_carry_we),
        .wb_sel     (id_wb_sel),
        .is_jump    (id_is_jump),
        .is_jz      (id_is_jz)
    );

    // ID/EX pipeline register carries both data fields and control.
    wire [3:0]  ex_alu_opcode;
    wire        ex_reg_we;
    wire        ex_mem_we;
    wire        ex_zero_we;
    wire        ex_carry_we;
    wire [1:0]  ex_wb_sel;
    wire        ex_is_jump;
    wire        ex_is_jz;
    wire [1:0]  ex_rd;
    wire [1:0]  ex_rs;
    wire [3:0]  ex_pc;
    wire        ex_valid;
    wire [11:0] ex_instruction;

    cpu_pipeline_register_id_ex id_ex_pipeline_register (
        .clk                (clk),
        .rst                (rst),
        .flush              (pipeline_flush),
        .alu_opcode_in      (id_alu_opcode),
        .reg_we_in          (id_reg_we),
        .mem_we_in          (id_mem_we),
        .zero_we_in         (id_zero_we),
        .carry_we_in        (id_carry_we),
        .wb_sel_in          (id_wb_sel),
        .is_jump_in         (id_is_jump),
        .is_jz_in           (id_is_jz),
        .rd_in              (id_rd),
        .rs_in              (id_rs),
        .immediate_in       (id_immediate),
        .pc_in              (id_pc),
        .valid_in           (id_valid),
        .instruction_in     (id_instruction),
        .alu_opcode_out     (ex_alu_opcode),
        .reg_we_out         (ex_reg_we),
        .mem_we_out         (ex_mem_we),
        .zero_we_out        (ex_zero_we),
        .carry_we_out       (ex_carry_we),
        .wb_sel_out         (ex_wb_sel),
        .is_jump_out        (ex_is_jump),
        .is_jz_out          (ex_is_jz),
        .rd_out             (ex_rd),
        .rs_out             (ex_rs),
        .immediate_out      (ex_immediate),
        .pc_out             (ex_pc),
        .valid_out          (ex_valid),
        .instruction_out    (ex_instruction)
    );

    // -----------------------------------------------------------------
    // Stage 3: EX - operand read, ALU, memory and write-back.
    // -----------------------------------------------------------------
    wire [3:0] rd_value;
    wire [3:0] rs_value;
    reg  [3:0] writeback_data;
    wire       register_write_enable;

    wire [7:0] alu_result_full;
    wire [3:0] alu_result;
    wire       alu_carry;
    wire       alu_zero;
    wire       alu_overflow;
    wire       alu_negative;
    wire       alu_busy;
    wire       alu_done;
    wire       alu_div_by_zero;

    wire [3:0] memory_read_data;
    wire       memory_write_enable;
    wire       zero_write_enable;
    wire       carry_write_enable;
    wire       zero_flag;
    wire       carry_flag;

    assign register_write_enable = ex_valid & ex_reg_we;
    assign memory_write_enable   = ex_valid & ex_mem_we;
    assign zero_write_enable     = ex_valid & ex_zero_we;
    assign carry_write_enable    = ex_valid & ex_carry_we;

    // The branch is resolved in EX. Both younger instructions are flushed.
    assign branch_taken = ex_valid &
                          (ex_is_jump | (ex_is_jz & zero_flag));

    register_file_4x4 registers (
        .clk          (clk),
        .rst          (rst),
        .read_addr_a  (ex_rd),
        .read_addr_b  (ex_rs),
        .write_addr   (ex_rd),
        .write_data   (writeback_data),
        .write_enable (register_write_enable),
        .read_data_a  (rd_value),
        .read_data_b  (rs_value)
    );

    // The CPU ISA currently maps only the basic ALU operations 0-5.
    // start remains low so the sequential MUL/DIV block is never launched.
    alu_4bit alu (
        .clk         (clk),
        .rst         (rst),
        .start       (1'b0),
        .a           (rd_value),
        .b           (rs_value),
        .opcode      (ex_alu_opcode),
        .result      (alu_result_full),
        .carry       (alu_carry),
        .zero        (alu_zero),
        .overflow    (alu_overflow),
        .negative    (alu_negative),
        .busy        (alu_busy),
        .done        (alu_done),
        .div_by_zero (alu_div_by_zero)
    );

    assign alu_result = alu_result_full[3:0];

    data_memory_16x4 data_memory (
        .clk          (clk),
        .address      (ex_immediate),
        .write_data   (rd_value),
        .write_enable (memory_write_enable),
        .read_data    (memory_read_data)
    );

    always @* begin
        case (ex_wb_sel)
            WB_ALU: writeback_data = alu_result;
            WB_IMM: writeback_data = ex_immediate;
            WB_RS:  writeback_data = rs_value;
            WB_MEM: writeback_data = memory_read_data;
            default: writeback_data = 4'b0000;
        endcase
    end

    flag_register flags (
        .clk        (clk),
        .rst        (rst),
        .zero_we    (zero_write_enable),
        .carry_we   (carry_write_enable),
        .zero_in    (alu_zero),
        .carry_in   (alu_carry),
        .zero_flag  (zero_flag),
        .carry_flag (carry_flag)
    );

    // Debug outputs. state_out is retained for compatibility and now means
    // "the EX stage contains a valid instruction".
    assign pc_out             = pc;
    assign instruction_out    = ex_instruction;
    assign state_out          = ex_valid;
    assign alu_result_out     = alu_result;
    assign writeback_data_out = writeback_data;
    assign zero_flag_out      = zero_flag;
    assign carry_flag_out     = carry_flag;
    assign id_pc_out          = id_pc;
    assign ex_pc_out          = ex_pc;
    assign id_instruction_out = id_instruction;
    assign if_id_valid_out    = id_valid;
    assign id_ex_valid_out    = ex_valid;
    assign flush_out          = pipeline_flush;

endmodule


// ID/EX pipeline register. Keeping it in this source file lets the existing
// Vivado project source set remain valid while making the new stage explicit.
module cpu_pipeline_register_id_ex (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,
    input  wire [3:0]  alu_opcode_in,
    input  wire        reg_we_in,
    input  wire        mem_we_in,
    input  wire        zero_we_in,
    input  wire        carry_we_in,
    input  wire [1:0]  wb_sel_in,
    input  wire        is_jump_in,
    input  wire        is_jz_in,
    input  wire [1:0]  rd_in,
    input  wire [1:0]  rs_in,
    input  wire [3:0]  immediate_in,
    input  wire [3:0]  pc_in,
    input  wire        valid_in,
    input  wire [11:0] instruction_in,
    output reg  [3:0]  alu_opcode_out,
    output reg         reg_we_out,
    output reg         mem_we_out,
    output reg         zero_we_out,
    output reg         carry_we_out,
    output reg  [1:0]  wb_sel_out,
    output reg         is_jump_out,
    output reg         is_jz_out,
    output reg  [1:0]  rd_out,
    output reg  [1:0]  rs_out,
    output reg  [3:0]  immediate_out,
    output reg  [3:0]  pc_out,
    output reg         valid_out,
    output reg  [11:0] instruction_out
);

    always @(posedge clk) begin
        if (rst || flush) begin
            alu_opcode_out  <= 4'b0000;
            reg_we_out      <= 1'b0;
            mem_we_out      <= 1'b0;
            zero_we_out     <= 1'b0;
            carry_we_out    <= 1'b0;
            wb_sel_out      <= 2'b00;
            is_jump_out     <= 1'b0;
            is_jz_out       <= 1'b0;
            rd_out          <= 2'b00;
            rs_out          <= 2'b00;
            immediate_out   <= 4'b0000;
            pc_out          <= 4'b0000;
            valid_out       <= 1'b0;
            instruction_out <= 12'hC00;
        end else begin
            alu_opcode_out  <= alu_opcode_in;
            reg_we_out      <= reg_we_in;
            mem_we_out      <= mem_we_in;
            zero_we_out     <= zero_we_in;
            carry_we_out    <= carry_we_in;
            wb_sel_out      <= wb_sel_in;
            is_jump_out     <= is_jump_in;
            is_jz_out       <= is_jz_in;
            rd_out          <= rd_in;
            rs_out          <= rs_in;
            immediate_out   <= immediate_in;
            pc_out          <= pc_in;
            valid_out       <= valid_in;
            instruction_out <= instruction_in;
        end
    end

endmodule
