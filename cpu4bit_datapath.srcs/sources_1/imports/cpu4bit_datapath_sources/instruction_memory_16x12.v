`timescale 1ns / 1ps

module instruction_memory_16x12 #(
    parameter PROGRAM_FILE = "program.mem"
) (
    input  wire [3:0]  address,
    output wire [11:0] instruction
);

    reg [11:0] mem [0:15];
    integer i;

    initial begin
        // Reserved opcode C is used as a harmless NOP in empty locations.
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 12'hC00;

        $readmemh(PROGRAM_FILE, mem);
    end

    assign instruction = mem[address];

endmodule
