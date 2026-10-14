`timescale 1ns / 1ps

module cpu_4bit_tb;

    reg clk;
    reg rst;

    wire [3:0]  pc_out;
    wire [11:0] instruction_out;
    wire        state_out;
    wire [3:0]  alu_result_out;
    wire [3:0]  writeback_data_out;
    wire        zero_flag_out;
    wire        carry_flag_out;
    wire [3:0]  id_pc_out;
    wire [3:0]  ex_pc_out;
    wire [11:0] id_instruction_out;
    wire        if_id_valid_out;
    wire        id_ex_valid_out;
    wire        flush_out;

    integer tests;
    integer errors;
    integer i;

    cpu_4bit_top #(
        .PROGRAM_FILE("program.mem")
    ) dut (
        .clk                (clk),
        .rst                (rst),
        .pc_out             (pc_out),
        .instruction_out    (instruction_out),
        .state_out          (state_out),
        .alu_result_out     (alu_result_out),
        .writeback_data_out (writeback_data_out),
        .zero_flag_out      (zero_flag_out),
        .carry_flag_out     (carry_flag_out),
        .id_pc_out          (id_pc_out),
        .ex_pc_out          (ex_pc_out),
        .id_instruction_out (id_instruction_out),
        .if_id_valid_out    (if_id_valid_out),
        .id_ex_valid_out    (id_ex_valid_out),
        .flush_out          (flush_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // One line per clock shows the three overlapped pipeline stages.
    always @(negedge clk) begin
        if (!rst) begin
            $display("IF pc=%h | ID valid=%b pc=%h instr=%h | EX valid=%b pc=%h instr=%h | WB=%h Z=%b C=%b",
                     pc_out,
                     if_id_valid_out, id_pc_out, id_instruction_out,
                     id_ex_valid_out, ex_pc_out, instruction_out,
                     writeback_data_out, zero_flag_out, carry_flag_out);
        end
    end

    task check4;
        input [8*56-1:0] test_name;
        input [3:0] actual;
        input [3:0] expected;
        begin
            tests = tests + 1;
            if (actual === expected) begin
                $display("PASS %-56s actual=%h", test_name, actual);
            end else begin
                errors = errors + 1;
                $display("FAIL %-56s actual=%h expected=%h",
                         test_name, actual, expected);
            end
        end
    endtask

    task check1;
        input [8*56-1:0] test_name;
        input actual;
        input expected;
        begin
            tests = tests + 1;
            if (actual === expected) begin
                $display("PASS %-56s actual=%b", test_name, actual);
            end else begin
                errors = errors + 1;
                $display("FAIL %-56s actual=%b expected=%b",
                         test_name, actual, expected);
            end
        end
    endtask

    // Wait until an instruction is in EX, then wait for the next edge where
    // its architectural write, memory write, flag update or branch commits.
    task finish_instruction;
        input [3:0] address;
        integer guard;
        begin
            guard = 0;

            while (!((id_ex_valid_out === 1'b1) &&
                     (ex_pc_out === address)) && (guard < 80)) begin
                @(negedge clk);
                guard = guard + 1;
            end

            if (guard >= 80) begin
                tests = tests + 1;
                errors = errors + 1;
                $display("FAIL timeout waiting for EX instruction at PC=%h",
                         address);
            end else begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task reset_cpu;
        begin
            rst = 1'b1;
            repeat (2) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            #1;
        end
    endtask

    task clear_program_and_data;
        begin
            rst = 1'b1;
            for (i = 0; i < 16; i = i + 1) begin
                dut.instruction_memory.mem[i] = 12'hC00;
                dut.data_memory.mem[i] = 4'h0;
            end
        end
    endtask

    task load_demo_program;
        begin
            clear_program_and_data;
            dut.instruction_memory.mem[0] = 12'h645; // LDI R1, 5
            dut.instruction_memory.mem[1] = 12'h683; // LDI R2, 3
            dut.instruction_memory.mem[2] = 12'h060; // ADD R1, R2
            dut.instruction_memory.mem[3] = 12'h6CA; // LDI R3, A
            dut.instruction_memory.mem[4] = 12'h470; // XOR R1, R3
            dut.instruction_memory.mem[5] = 12'hA05; // JMP 5
        end
    endtask

    task load_memory_branch_program;
        begin
            clear_program_and_data;
            dut.instruction_memory.mem[0]  = 12'h645; // LDI R1, 5
            dut.instruction_memory.mem[1]  = 12'h683; // LDI R2, 3
            dut.instruction_memory.mem[2]  = 12'h060; // ADD R1, R2 -> 8
            dut.instruction_memory.mem[3]  = 12'h940; // STORE R1, [0]
            dut.instruction_memory.mem[4]  = 12'h800; // LOAD R0, [0]
            dut.instruction_memory.mem[5]  = 12'h1A0; // SUB R2, R2 -> Z=1
            dut.instruction_memory.mem[6]  = 12'hB09; // JZ 9
            dut.instruction_memory.mem[7]  = 12'h6CF; // flushed
            dut.instruction_memory.mem[8]  = 12'h6CE; // flushed
            dut.instruction_memory.mem[9]  = 12'h7C0; // MOV R3, R0
            dut.instruction_memory.mem[10] = 12'hA0A; // JMP 10
        end
    endtask

    task load_logic_program;
        begin
            clear_program_and_data;
            dut.instruction_memory.mem[0]  = 12'h60C; // LDI R0, C
            dut.instruction_memory.mem[1]  = 12'h64A; // LDI R1, A
            dut.instruction_memory.mem[2]  = 12'h210; // AND R0, R1 -> 8
            dut.instruction_memory.mem[3]  = 12'h310; // OR  R0, R1 -> A
            dut.instruction_memory.mem[4]  = 12'h500; // NOT R0 -> 5
            dut.instruction_memory.mem[5]  = 12'hB08; // JZ 8, not taken
            dut.instruction_memory.mem[6]  = 12'h410; // XOR R0, R1 -> F
            dut.instruction_memory.mem[7]  = 12'hA09; // JMP 9
            dut.instruction_memory.mem[8]  = 12'h68F; // flushed
            dut.instruction_memory.mem[9]  = 12'h780; // MOV R2, R0
            dut.instruction_memory.mem[10] = 12'hA0A; // JMP 10
        end
    endtask

    initial begin
        tests  = 0;
        errors = 0;
        rst    = 1'b1;

        $display("Student name: Vuong Tri Tien");
        $display("Roll number: HE190717");
        $display("Architecture: 3-stage IF/ID/EX pipeline");

        // TEST 1: pipeline fill, LDI, ADD, XOR and JMP flush.
        $display("\n===== TEST 1: pipeline fill and demo program =====");
        load_demo_program;
        reset_cpu;

        check4("PC is zero after reset", pc_out, 4'h0);
        check1("IF/ID is empty after reset", if_id_valid_out, 1'b0);
        check1("ID/EX is empty after reset", id_ex_valid_out, 1'b0);

        @(posedge clk);
        #1;
        check4("First clock fetches address 0 into ID", id_pc_out, 4'h0);
        check1("IF/ID is valid after first fetch", if_id_valid_out, 1'b1);
        check1("EX is still a bubble after first fetch", id_ex_valid_out, 1'b0);

        @(posedge clk);
        #1;
        check4("Pipeline overlap: IF is fetching address 2", pc_out, 4'h2);
        check4("Pipeline overlap: ID holds address 1", id_pc_out, 4'h1);
        check4("Pipeline overlap: EX holds address 0", ex_pc_out, 4'h0);
        check1("EX becomes valid after two pipeline transfers",
               id_ex_valid_out, 1'b1);

        finish_instruction(4'h2);
        check4("ADD R1,R2 gives R1=8", dut.registers.r1, 4'h8);
        check4("R2 remains 3", dut.registers.r2, 4'h3);
        check1("ADD Zero flag is clear", zero_flag_out, 1'b0);
        check1("ADD Carry flag is clear", carry_flag_out, 1'b0);

        finish_instruction(4'h4);
        check4("XOR R1,R3 gives R1=2", dut.registers.r1, 4'h2);
        check4("LDI loaded R3=A", dut.registers.r3, 4'hA);
        check1("XOR Zero flag is clear", zero_flag_out, 1'b0);

        finish_instruction(4'h5);
        check4("JMP 5 redirects fetch PC to 5", pc_out, 4'h5);
        check1("Taken JMP flushes IF/ID", if_id_valid_out, 1'b0);
        check1("Taken JMP flushes ID/EX", id_ex_valid_out, 1'b0);

        // TEST 2: STORE, LOAD, SUB, taken JZ and MOV.
        $display("\n===== TEST 2: memory and taken branch =====");
        load_memory_branch_program;
        reset_cpu;

        finish_instruction(4'h3);
        check4("STORE wrote 8 to data_memory[0]",
               dut.data_memory.mem[0], 4'h8);

        finish_instruction(4'h4);
        check4("LOAD copied data_memory[0] to R0",
               dut.registers.r0, 4'h8);

        finish_instruction(4'h5);
        check4("SUB R2,R2 gives zero", dut.registers.r2, 4'h0);
        check1("SUB set Zero flag", zero_flag_out, 1'b1);
        check1("SUB set Carry as no-borrow", carry_flag_out, 1'b1);

        finish_instruction(4'h6);
        check4("Taken JZ redirects fetch PC to 9", pc_out, 4'h9);
        check1("Taken JZ flushes IF/ID", if_id_valid_out, 1'b0);
        check1("Taken JZ flushes ID/EX", id_ex_valid_out, 1'b0);

        finish_instruction(4'h9);
        check4("MOV R3,R0 gives R3=8", dut.registers.r3, 4'h8);
        check4("Instructions at 7 and 8 did not change R3",
               dut.registers.r3, 4'h8);

        // TEST 3: AND, OR, NOT, not-taken JZ, XOR and JMP.
        $display("\n===== TEST 3: logic and not-taken branch =====");
        load_logic_program;
        reset_cpu;

        finish_instruction(4'h2);
        check4("AND C,A gives R0=8", dut.registers.r0, 4'h8);

        finish_instruction(4'h3);
        check4("OR 8,A gives R0=A", dut.registers.r0, 4'hA);

        finish_instruction(4'h4);
        check4("NOT A gives R0=5", dut.registers.r0, 4'h5);
        check1("NOT result keeps Zero clear", zero_flag_out, 1'b0);
        check1("Logic operation preserved previous Carry",
               carry_flag_out, 1'b0);

        finish_instruction(4'h5);
        check1("Not-taken JZ does not request a flush", flush_out, 1'b0);
        check4("Instruction after not-taken JZ reaches EX",
               ex_pc_out, 4'h6);

        finish_instruction(4'h6);
        check4("XOR 5,A gives R0=F", dut.registers.r0, 4'hF);

        finish_instruction(4'h7);
        check4("JMP 9 redirects fetch PC to 9", pc_out, 4'h9);
        check1("JMP 9 creates an EX bubble", id_ex_valid_out, 1'b0);

        finish_instruction(4'h9);
        check4("MOV R2,R0 gives R2=F", dut.registers.r2, 4'hF);
        check4("Flushed address 8 did not write R2", dut.registers.r2, 4'hF);

        if (errors == 0)
            $display("PASS: ALL %0d PIPELINED CPU CHECKS PASSED", tests);
        else
            $display("FAIL: %0d OF %0d PIPELINED CPU CHECKS FAILED",
                     errors, tests);
        $finish;
    end

endmodule
