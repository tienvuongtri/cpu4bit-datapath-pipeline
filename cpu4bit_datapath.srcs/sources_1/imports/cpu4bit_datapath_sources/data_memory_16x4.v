`timescale 1ns / 1ps

module data_memory_16x4 (
    input  wire       clk,
    input  wire [3:0] address,
    input  wire [3:0] write_data,
    input  wire       write_enable,
    output wire [3:0] read_data
);

    reg [3:0] mem [0:15];
    integer i;

    initial begin
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 4'b0000;
    end

    always @(posedge clk) begin
        if (write_enable)
            mem[address] <= write_data;
    end

    assign read_data = mem[address];

endmodule
