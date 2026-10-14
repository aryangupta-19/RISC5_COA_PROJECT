`timescale 1ns/1ps
// Minimal SoC wrapper: 256 x 32-bit instruction words and 256 x 32-bit data words.
// Memories are byte-addressed through word index addr[9:2], little-endian subword lanes.
module riscv_single_cycle_soc (
    input wire clk,
    input wire reset,
    output wire [31:0] pc,
    output wire [31:0] current_instr,
    output wire [31:0] debug_wb_value,
    output wire [4:0] debug_wb_rd,
    output wire debug_wb_en,
    output wire debug_mem_we
);
    reg [31:0] instr_mem [0:255];
    reg [31:0] data_mem  [0:255];

    wire [31:0] data_addr;
    wire [31:0] data_wdata;
    wire [3:0] data_wstrb;
    wire [31:0] data_rdata;
    wire [31:0] unused_instr;
    integer i;

    assign current_instr = instr_mem[pc[9:2]];
    assign data_rdata = data_mem[data_addr[9:2]];

    riscv_single_cycle_cpu cpu (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .instr(current_instr),
        .data_addr(data_addr),
        .data_wdata(data_wdata),
        .data_wstrb(data_wstrb),
        .data_rdata(data_rdata),
        .debug_instr(unused_instr),
        .debug_wb_value(debug_wb_value),
        .debug_wb_rd(debug_wb_rd),
        .debug_wb_en(debug_wb_en),
        .debug_mem_we(debug_mem_we)
    );

    // Data memory writes; byte strobes allow SB, SH and SW.
    always @(posedge clk) begin
        if (!reset && data_wstrb != 4'b0000) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (data_wstrb[i])
                    data_mem[data_addr[9:2]][8*i +: 8] <= data_wdata[8*i +: 8];
            end
        end
    end

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            instr_mem[i] = 32'h00000013; // ADDI x0,x0,0 (NOP)
            data_mem[i] = 32'd0;
        end
        $readmemh("program.hex", instr_mem);
    end
endmodule
