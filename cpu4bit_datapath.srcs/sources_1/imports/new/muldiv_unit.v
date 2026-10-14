`timescale 1ns / 1ps

// Unsigned, iterative 4-bit multiplier/divider.
// It borrows the shared 4-bit adder through add_a/add_b/add_sub and receives
// the resulting sum/carry through adder_sum/adder_carry.
module muldiv_unit (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       operation_div,
    input  wire [3:0] operand_a,
    input  wire [3:0] operand_b,

    output wire [3:0] add_a,
    output wire [3:0] add_b,
    output wire       add_sub,
    input  wire [3:0] adder_sum,
    input  wire       adder_carry,

    output reg  [7:0] result,
    output reg        busy,
    output reg        done,
    output reg        div_by_zero
);

    reg [3:0] accumulator;
    reg [3:0] q_register;
    reg [3:0] m_register;
    reg [2:0] count;
    reg       mode_div;

    wire [3:0] shifted_dividend_high;
    wire [3:0] mul_acc_next;
    wire [3:0] mul_q_next;
    wire [3:0] div_acc_next;
    wire [3:0] div_q_next;

    // In division the shared adder evaluates the trial subtraction after the
    // combined {remainder, quotient} register has been shifted left.
    assign shifted_dividend_high = {accumulator[2:0], q_register[3]};

    assign add_a   = mode_div ? shifted_dividend_high : accumulator;
    assign add_b   = m_register;
    assign add_sub = mode_div;

    // Classic add-and-shift-right multiplier step.
    assign mul_acc_next = q_register[0]
                        ? {adder_carry, adder_sum[3:1]}
                        : {1'b0, accumulator[3:1]};
    assign mul_q_next   = q_register[0]
                        ? {adder_sum[0], q_register[3:1]}
                        : {accumulator[0], q_register[3:1]};

    // Restoring division: adder_carry=1 means the trial subtraction did not
    // borrow, so the new remainder is accepted and the quotient bit is one.
    assign div_acc_next = adder_carry ? adder_sum : shifted_dividend_high;
    assign div_q_next   = {q_register[2:0], adder_carry};

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 4'b0000;
            q_register   <= 4'b0000;
            m_register   <= 4'b0000;
            count        <= 3'd0;
            mode_div     <= 1'b0;
            result       <= 8'h00;
            busy         <= 1'b0;
            done         <= 1'b0;
            div_by_zero  <= 1'b0;
        end else begin
            // Status outputs are one-clock pulses.
            done        <= 1'b0;
            div_by_zero <= 1'b0;

            if (!busy) begin
                if (start) begin
                    if (operation_div && (operand_b == 4'b0000)) begin
                        result      <= 8'h00;
                        busy        <= 1'b0;
                        done        <= 1'b1;
                        div_by_zero <= 1'b1;
                    end else begin
                        accumulator <= 4'b0000;
                        q_register   <= operation_div ? operand_a : operand_b;
                        m_register   <= operation_div ? operand_b : operand_a;
                        count        <= 3'd0;
                        mode_div     <= operation_div;
                        busy         <= 1'b1;
                    end
                end
            end else if (mode_div) begin
                accumulator <= div_acc_next;
                q_register   <= div_q_next;

                if (count == 3'd3) begin
                    // High nibble = remainder, low nibble = quotient.
                    result <= {div_acc_next, div_q_next};
                    busy   <= 1'b0;
                    done   <= 1'b1;
                end else begin
                    count <= count + 3'd1;
                end
            end else begin
                accumulator <= mul_acc_next;
                q_register   <= mul_q_next;

                if (count == 3'd3) begin
                    result <= {mul_acc_next, mul_q_next};
                    busy   <= 1'b0;
                    done   <= 1'b1;
                end else begin
                    count <= count + 3'd1;
                end
            end
        end
    end

endmodule

