`timescale 1ns/1ps
// Simple single-cycle RV32I-subset CPU.
// 32 x 32-bit integer registers (x0 hardwired to zero).
// Instruction and data memories are in riscv_single_cycle_soc.v.
module riscv_single_cycle_cpu (
    input wire clk,
    input wire reset,
    output reg [31:0] pc,
    input wire [31:0] instr,
    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    output wire [3:0] data_wstrb,
    input wire [31:0] data_rdata,
    output wire [31:0] debug_instr,
    output wire [31:0] debug_wb_value,
    output wire [4:0] debug_wb_rd,
    output wire debug_wb_en,
    output wire debug_mem_we
);
    reg [31:0] regs [0:31];
//instructions se components utha rahe hai
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    reg [31:0] imm;
    reg [31:0] src_a, src_b;
    reg [31:0] alu_b;
    reg [31:0] alu_result;
    reg [3:0] alu_ctrl;
    reg reg_write, mem_read, mem_write, use_imm, is_load, is_store;
    reg branch_taken, is_branch, is_jal, is_jalr, is_lui, is_auipc;
    reg [31:0] next_pc, wb_value, effective_addr;
    reg [3:0] store_mask;
    reg [31:0] store_value;
    integer i;
// code for ALU operations
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_SLL  = 4'd2;
    localparam ALU_SLT  = 4'd3;
    localparam ALU_SLTU = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_OR   = 4'd8;
    localparam ALU_AND  = 4'd9;
    localparam ALU_COPY_B = 4'd10;
// baad me hum alu_ctrl = ALU_ADD aisa kuch karenge

// debugging outputs and cpu connections 
// internal cpu signaks --> output ports
    assign debug_instr = instr;
    assign debug_wb_value = wb_value;
    assign debug_wb_rd = rd;
    assign debug_wb_en = reg_write && (rd != 0);
    assign debug_mem_we = mem_write;
    assign data_addr = effective_addr;
    assign data_wdata = store_value;
    assign data_wstrb = store_mask;

    // Immediate decode
    // we will extract immediate from instructions
    always @* begin
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: imm = {{20{instr[31]}}, instr[31:20]}; // i - format
            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            7'b0110111, 7'b0010111: imm = {instr[31:12], 12'b0};
            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default: imm = 32'd0;
        endcase
    end

    // Register reads and default controls.
    // 
    always @* begin
        src_a = (rs1 == 0) ? 32'd0 : regs[rs1];
        src_b = (rs2 == 0) ? 32'd0 : regs[rs2];
        alu_b = src_b;
        alu_ctrl = ALU_ADD;
        reg_write = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        use_imm = 1'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        is_branch = 1'b0;
        is_jal = 1'b0;
        is_jalr = 1'b0;
        is_lui = 1'b0;
        is_auipc = 1'b0;
        branch_taken = 1'b0;
        next_pc = pc + 32'd4;
        wb_value = 32'd0;
        effective_addr = src_a + imm;
        store_mask = 4'b0000;
        store_value = src_b;
        alu_result = 32'd0;

        case (opcode)
            7'b0110011: begin // R format
                reg_write = 1'b1;
                case ({funct7,funct3})
                    {7'b0000000,3'b000}: alu_ctrl = ALU_ADD; // ADD
                    {7'b0100000,3'b000}: alu_ctrl = ALU_SUB; // SUB
                    {7'b0000000,3'b001}: alu_ctrl = ALU_SLL; // SLL
                    {7'b0000000,3'b010}: alu_ctrl = ALU_SLT; // SLT
                    {7'b0000000,3'b011}: alu_ctrl = ALU_SLTU; // SLTU
                    {7'b0000000,3'b100}: alu_ctrl = ALU_XOR; // XOR
                    {7'b0000000,3'b101}: alu_ctrl = ALU_SRL; // SRL
                    {7'b0100000,3'b101}: alu_ctrl = ALU_SRA; // SRA
                    {7'b0000000,3'b110}: alu_ctrl = ALU_OR;  // OR
                    {7'b0000000,3'b111}: alu_ctrl = ALU_AND; // AND
                    default: alu_ctrl = ALU_ADD;
                endcase
                alu_result = alu_compute(src_a, src_b, alu_ctrl);
                wb_value = alu_result;
            end
            7'b0010011: begin // I-format arithmetic/logical
                reg_write = 1'b1;
                use_imm = 1'b1;
                alu_b = imm;
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;  // ADDI
                    3'b010: alu_ctrl = ALU_SLT;  // SLTI
                    3'b011: alu_ctrl = ALU_SLTU; // SLTIU
                    3'b100: alu_ctrl = ALU_XOR;  // XORI
                    3'b110: alu_ctrl = ALU_OR;   // ORI
                    3'b111: alu_ctrl = ALU_AND;  // ANDI
                    3'b001: alu_ctrl = ALU_SLL;  // SLLI
                    3'b101: alu_ctrl = instr[30] ? ALU_SRA : ALU_SRL; // SRAI/SRLI
                    default: alu_ctrl = ALU_ADD;
                endcase
                if (funct3 == 3'b001 || funct3 == 3'b101) alu_b = {27'd0, instr[24:20]};
                alu_result = alu_compute(src_a, alu_b, alu_ctrl);
                wb_value = alu_result;
            end
            7'b0000011: begin // Loads
                reg_write = 1'b1;
                mem_read = 1'b1;
                is_load = 1'b1;
                wb_value = load_value(data_rdata, effective_addr[1:0], funct3);
            end
            7'b0100011: begin // Stores
                mem_write = 1'b1;
                is_store = 1'b1;
                case (funct3)
                    3'b000: begin store_mask = 4'b0001 << effective_addr[1:0]; store_value = src_b << (8*effective_addr[1:0]); end // SB
                    3'b001: begin store_mask = 4'b0011 << effective_addr[1:0]; store_value = src_b << (8*effective_addr[1:0]); end // SH
                    3'b010: begin store_mask = 4'b1111; store_value = src_b; end // SW aligned
                    default: begin store_mask = 4'b0000; store_value = src_b; end
                endcase
            end
            7'b1100011: begin // Branches
                is_branch = 1'b1;
                case (funct3)
                    3'b000: branch_taken = (src_a == src_b); // BEQ
                    3'b001: branch_taken = (src_a != src_b); // BNE
                    3'b100: branch_taken = ($signed(src_a) < $signed(src_b)); // BLT
                    3'b101: branch_taken = ($signed(src_a) >= $signed(src_b)); // BGE
                    3'b110: branch_taken = (src_a < src_b); // BLTU
                    3'b111: branch_taken = (src_a >= src_b); // BGEU
                    default: branch_taken = 1'b0;
                endcase
                if (branch_taken) next_pc = pc + imm;
            end
            7'b1101111: begin // JAL
                reg_write = 1'b1;
                is_jal = 1'b1;
                wb_value = pc + 32'd4;
                next_pc = pc + imm;
            end
            7'b1100111: begin // JALR
                reg_write = 1'b1;
                is_jalr = 1'b1;
                wb_value = pc + 32'd4;
                next_pc = (src_a + imm) & 32'hfffffffe;
            end
            7'b0110111: begin // LUI
                reg_write = 1'b1;
                is_lui = 1'b1;
                wb_value = imm;
            end
            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                is_auipc = 1'b1;
                wb_value = pc + imm;
            end
            default: begin
                // Unsupported/zero word behaves as a no-op.
            end
        endcase
    end

    function [31:0] alu_compute;
        input [31:0] a;
        input [31:0] b;
        input [3:0] ctrl;
        begin
            case (ctrl)
                ALU_ADD: alu_compute = a + b;
                ALU_SUB: alu_compute = a - b;
                ALU_SLL: alu_compute = a << b[4:0];
                ALU_SLT: alu_compute = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                ALU_SLTU: alu_compute = (a < b) ? 32'd1 : 32'd0;
                ALU_XOR: alu_compute = a ^ b;
                ALU_SRL: alu_compute = a >> b[4:0];
                ALU_SRA: alu_compute = $signed(a) >>> b[4:0];
                ALU_OR: alu_compute = a | b;
                ALU_AND: alu_compute = a & b;
                default: alu_compute = b;
            endcase
        end
    endfunction

    function [31:0] load_value;
        input [31:0] word_data;
        input [1:0] byte_offset;
        input [2:0] f3;
        reg [31:0] shifted;
        begin
            shifted = word_data >> (8*byte_offset);
            case (f3)
                3'b000: load_value = {{24{shifted[7]}}, shifted[7:0]};  // LB
                3'b001: load_value = {{16{shifted[15]}}, shifted[15:0]}; // LH
                3'b010: load_value = word_data;                         // LW
                3'b100: load_value = {24'd0, shifted[7:0]};             // LBU
                3'b101: load_value = {16'd0, shifted[15:0]};             // LHU
                default: load_value = word_data;
            endcase
        end
    endfunction

    // State changes once per clock edge. x0 is kept at zero.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;
        end else begin
            if (reg_write && rd != 0) regs[rd] <= wb_value;
            regs[0] <= 32'd0;
            pc <= next_pc;
        end
    end
endmodule
