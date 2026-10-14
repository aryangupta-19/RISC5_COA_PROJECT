`timescale 1ns/1ps
// Standalone Verilog runner. No testbench file and no Python are required.
// Runs instructions from program.hex until the program reaches a self-loop,
// reaches MAX_CYCLES, or the simulation is stopped.
module riscv_run;
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] wb_value;
    wire [4:0] wb_rd;
    wire wb_en;
    wire mem_we;
    integer cycles;
    integer j;

    parameter MAX_CYCLES = 256;

    riscv_single_cycle_soc dut (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .current_instr(instr),
        .debug_wb_value(wb_value),
        .debug_wb_rd(wb_rd),
        .debug_wb_en(wb_en),
        .debug_mem_we(mem_we)
    );

    always #5 clk = ~clk;

    initial begin
        $display("==============================================");
        $display("Simple single-cycle RISC-V processor (Verilog)");
        $display("Instruction memory: 256 x 32-bit words");
        $display("Data memory:        256 x 32-bit words");
        $display("Register file:      32 x 32-bit registers");
        $display("==============================================");
        repeat (2) @(posedge clk);
        #1 reset = 1'b0;

        for (cycles = 0; cycles < MAX_CYCLES; cycles = cycles + 1) begin
            @(negedge clk);
            $display("cycle=%0d  PC=0x%08h  INSTR=0x%08h", cycles, pc, instr);
            if (wb_en)
                $display("  write-back: x%0d = 0x%08h (%0d)", wb_rd, wb_value, wb_value);
            if (mem_we)
                $display("  data-memory store executed");
            if (instr == 32'h0000006f && cycles > 0) begin
                $display("Self-loop detected (JAL x0,0); stopping.");
                cycles = MAX_CYCLES;
            end
            @(posedge clk);
            #1;
        end

        $display("");
        $display("Final PC = 0x%08h", pc);
        $display("Register file:");
        for (j = 0; j < 32; j = j + 1)
            $display("x%0d = 0x%08h (%0d)", j, dut.cpu.regs[j], dut.cpu.regs[j]);
        $display("Simulation finished.");
        $finish;
    end
endmodule
