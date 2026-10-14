# Verilog-only single-cycle RISC-V processor

This is a small Verilog-only RV32I-subset processor project. It does not use Python and contains no testbench suite or automated test cases.

## Hardware included

- Single-cycle 32-bit processor core
- 32 x 32-bit integer registers (`x0` is hardwired to zero)
- 256 x 32-bit instruction memory
- 256 x 32-bit data memory
- ALU, immediate decode, branch and jump logic
- Load/store support for byte, halfword and word accesses
- A minimal Verilog runner that supplies clock/reset and prints instruction activity

## Supported 37 instructions

- R: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- I arithmetic/logical: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
- Loads: LB, LH, LW, LBU, LHU
- Stores: SB, SH, SW
- U: LUI, AUIPC
- Branch: BEQ, BNE, BGE, BLT, BLTU, BGEU
- Jumps: JAL, JALR

## Run on Windows with Icarus Verilog

Open PowerShell in this directory. If Icarus Verilog is installed at `C:\iverilog\bin`, run this once in the current PowerShell window:

```powershell
$env:Path += ";C:\iverilog\bin"
```

Compile the Verilog files only:

```powershell
iverilog -g2005 -s riscv_run -o riscv_run riscv_alu.v riscv_single_cycle_cpu.v riscv_single_cycle_soc.v riscv_run.v
```

Run:

```powershell
vvp riscv_run
```

No Python, assembler, or testbench is used.

## Changing the program

Edit `program.hex`. Each line must be one 32-bit instruction encoded as eight hexadecimal digits. Instructions are fetched from address 0, 4, 8, and so on.

The supplied program is:

```asm
ADDI x1, x0, 10
ADDI x2, x0, 20
ADD  x3, x1, x2
JAL  x0, 0
```

Its machine code is:

```text
00a00093
01400113
002081b3
0000006f
```

The last instruction (`JAL x0, 0`) loops at its own address. The runner detects that self-loop and stops, then prints the register file. To run a different program, replace these words with the machine-code encodings of your desired instructions. Include a final `0000006f` when you want a predictable stop after a straight-line program.

## Important scope notes

- This is an educational RV32I subset implementation for the 37 requested instructions, not a complete privileged RISC-V implementation.
- The memory is word-array based and uses `addr[9:2]` as the word index; this models a 1 KiB range of byte addresses.
- Halfword and word accesses should use naturally aligned addresses. The core's intended data path supports byte strobes for stores and sign/zero extension for loads.
- There are no traps, interrupts, privilege modes, caches, MMU, or pipeline.
- The Verilog has not been simulated in this generation environment. Compile it with Icarus Verilog locally and address any compiler diagnostics if they appear.






















# Single-Cycle RISC-V Processor — Purpose of Each File

Your project implements a **simple 32-bit single-cycle RISC-V processor using Verilog**. It supports 37 instructions, has a 32-register register file, 256 instruction-memory words, and 256 data-memory words.

The main idea is to load machine instructions from `program.hex`, execute them sequentially, and display the execution results in the terminal.

## 1. Overview: How the Files Work Together

Your project contains six files:

| File                       | Purpose                                   | Why do we need it?                                                                              |
| -------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `riscv_alu.v`              | Implements the Arithmetic Logic Unit      | Performs arithmetic and logical operations such as ADD, SUB, AND, and OR.                       |
| `riscv_single_cycle_cpu.v` | Implements the processor                  | Fetches, decodes, and executes instructions, updates the PC, and writes results to registers.   |
| `riscv_single_cycle_soc.v` | Connects the processor with memory        | Provides instruction memory and data memory and connects them to the CPU.                       |
| `riscv_run.v`              | Runs the simulation and displays results  | Generates the clock and reset, monitors execution, and prints register updates in the terminal. |
| `program.hex`              | Stores the program's machine instructions | Tells the processor which instructions to execute.                                              |
| `README.md`                | Documents the project                     | Explains the architecture, files, compilation, and execution procedure.                         |

**The four Verilog files have different responsibilities:** the ALU performs calculations, the CPU controls execution, the SoC provides memory, and the runner starts and monitors the simulation.

Let's examine each one.

---

## 2. `riscv_alu.v` — Arithmetic Logic Unit

### What does it do?

The ALU performs the arithmetic and logical operations requested by the processor.

For example:

* `ADD`: Add two numbers.
* `SUB`: Subtract one number from another.
* `AND`: Perform a bitwise AND.
* `OR`: Perform a bitwise OR.
* `XOR`: Perform a bitwise XOR.
* `SLL`: Shift bits to the left.
* `SRL`: Shift bits to the right logically.
* `SRA`: Shift bits to the right arithmetically.
* `SLT`: Compare two signed numbers.
* `SLTU`: Compare two unsigned numbers.

### Why do we need it?

Consider this instruction:

```asm
ADD x3, x1, x2
```

Suppose:

```text
x1 = 10
x2 = 20
```

The processor must calculate:

$$
x3 = x1 + x2 = 10 + 20 = 30
$$

The ALU performs the addition and produces `30` as its result.

The CPU then writes that result into register `x3`.

### What is its role in your project?

The ALU is the **calculation unit**. It does not independently fetch instructions or decide which instruction to execute. The CPU determines which operation is required and supplies the appropriate operands.

---

## 3. `riscv_single_cycle_cpu.v` — The Processor

This is the central component of your project.

### What does it do?

It implements the logic required to execute the 37 supported RISC-V instructions.

Its main responsibilities are:

1. Maintain the Program Counter (PC).
2. Fetch an instruction from instruction memory.
3. Decode the instruction.
4. Read operands from the register file.
5. Determine the required operation.
6. Use the ALU when necessary.
7. Read from or write to data memory for load/store instructions.
8. Write results back into registers.
9. Calculate the address of the next instruction.

### Why do we need it?

Without the CPU, the ALU would simply be a calculation unit. It would not know which instructions to execute, where to obtain operands, or where to store results.

The CPU coordinates the entire execution process.

### Example

Suppose the program contains:

```asm
ADDI x1, x0, 10
ADDI x2, x0, 20
ADD  x3, x1, x2
```

The CPU executes these instructions in sequence.

**Instruction 1:**

```asm
ADDI x1, x0, 10
```

* Reads register `x0`, which always contains zero.
* Adds the immediate value `10`.
* Writes the result to `x1`.

Result:

```text
x1 = 10
```

**Instruction 2:**

```asm
ADDI x2, x0, 20
```

* Reads `x0`.
* Adds the immediate value `20`.
* Writes the result to `x2`.

Result:

```text
x2 = 20
```

**Instruction 3:**

```asm
ADD x3, x1, x2
```

* Reads `x1` and `x2`.
* Selects addition as the ALU operation.
* Writes the result to `x3`.

Result:

```text
x3 = 30
```

### What important components are implemented inside it?

| Component           | Responsibility                                                       |
| ------------------- | -------------------------------------------------------------------- |
| Program Counter     | Holds the address of the current instruction.                        |
| Instruction decoder | Determines the instruction type and required operation.              |
| Register file       | Stores 32 general-purpose 32-bit registers, `x0`–`x31`.              |
| Immediate generator | Extracts and sign-extends immediate values from instructions.        |
| ALU control         | Selects the appropriate arithmetic or logical operation.             |
| Branch/jump logic   | Determines the next PC for branches and jumps.                       |
| Load/store logic    | Handles memory access instructions and byte/halfword/word selection. |
| Write-back logic    | Selects the result that should be written to a register.             |

**Important:** In your implementation, these components are combined inside the CPU module rather than each being a separate Verilog file.

---

## 4. `riscv_single_cycle_soc.v` — Processor and Memory Integration

### What does it do?

This file connects the CPU to its instruction memory and data memory.

Here, **SoC** means *System on Chip*. In this project, the module provides a simple system containing the processor and its memories.

Your implementation contains:

* **Instruction memory:** 256 words, each 32 bits.
* **Data memory:** 256 words, each 32 bits.

Each memory therefore has a capacity of:

$$
256 \times 32 = 8192 \text{ bits}
$$

That is **1,024 bytes per memory**, or 1 KiB each.

### Why do we need it?

The CPU needs instructions to execute and a place to store or retrieve data.

The SoC provides both memories and connects them to the processor.

#### Instruction memory

Stores the machine instructions loaded from `program.hex`.

For example:

```text
Address 0x00 → First instruction
Address 0x04 → Second instruction
Address 0x08 → Third instruction
Address 0x0C → Fourth instruction
```

Each instruction is 4 bytes, so normal sequential execution advances the PC by four.

#### Data memory

Stores the data accessed by load and store instructions.

For example:

```asm
SW x1, 0(x2)
```

This instruction stores the 32-bit value in `x1` at the memory address calculated from `x2` and the immediate offset.

A corresponding load instruction can retrieve data from memory.

### Why are the memories separate?

The project uses separate instruction and data memories. This allows the CPU to fetch an instruction while accessing data through a separate memory interface.

It is a simple arrangement for this processor implementation.

---

## 5. `riscv_run.v` — Simulation Runner

### What does it do?

This file starts and monitors the processor simulation.

Its responsibilities include:

* Generating the clock signal.
* Applying the reset signal.
* Allowing the CPU to execute instructions.
* Displaying the current PC and instruction.
* Printing register write-back results.
* Detecting the designated `JAL x0, 0` self-loop used to stop this demonstration program.
* Displaying the final PC and register values.

### Why do we need it?

Verilog describes hardware behavior. To observe that behavior in a simulation, we need something to drive the hardware and display the results.

That is the role of `riscv_run.v`.

For example, it can display:

```text
cycle=0 PC=0x00000000 INSTR=0x00a00093
  write-back: x1 = 0x0000000a (10)

cycle=1 PC=0x00000004 INSTR=0x01400113
  write-back: x2 = 0x00000014 (20)

cycle=2 PC=0x00000008 INSTR=0x002081b3
  write-back: x3 = 0x0000001e (30)
```

This tells you that the processor executed the instructions and wrote the expected values to the registers.

### Is this a testbench?

It serves a similar simulation-driving role, but it is named `riscv_run.v` to act as the project's standalone runner.

You specifically requested a Verilog-only project without a separate testbench, and this runner is included as part of the Verilog simulation setup.

**Note:** The runner's stopping mechanism is designed around the self-loop in the sample program. It is not a general-purpose mechanism for detecting when arbitrary RISC-V programs have finished.

---

## 6. `program.hex` — The Program Executed by the Processor

### What does it do?

This file contains the machine-code instructions that the processor executes.

The CPU does not directly execute C or assembly source code. It executes encoded machine instructions.

For example, your current `program.hex` contains:

```text
00a00093
01400113
002081b3
0000006f
```

Each line represents one 32-bit instruction.

The instructions correspond to:

| Machine code | Assembly instruction | Purpose                                              |
| ------------ | -------------------- | ---------------------------------------------------- |
| `00a00093`   | `ADDI x1, x0, 10`    | Put 10 into `x1`.                                    |
| `01400113`   | `ADDI x2, x0, 20`    | Put 20 into `x2`.                                    |
| `002081b3`   | `ADD x3, x1, x2`     | Add `x1` and `x2`, storing 30 in `x3`.               |
| `0000006f`   | `JAL x0, 0`          | Jump to the same address, creating an infinite loop. |

### Why do we need it?

It provides the actual program for the processor to execute.

When the simulation starts, the SoC loads these machine-code words into instruction memory using:

```verilog
$readmemh("program.hex", instr_mem);
```

The CPU then fetches the instructions using the PC.

### Can you change the program?

Yes. You can replace the machine-code instructions with other valid RISC-V encodings to test different operations.

For example, to test subtraction, you could use:

```text
01900093
00a00113
402081b3
0000006f
```

These encode:

```asm
ADDI x1, x0, 25
ADDI x2, x0, 10
SUB  x3, x1, x2
JAL  x0, 0
```

The expected result is:

```text
x1 = 25
x2 = 10
x3 = 15
```

The last instruction keeps the processor in a self-loop, allowing the runner to stop the simulation.

---

## 7. `README.md` — Project Documentation

### What does it do?

It explains the project and how to use it.

It documents details such as:

* Project structure.
* Supported instructions.
* Memory and register sizes.
* Compilation commands.
* Simulation commands.
* Known limitations.

### Why do we need it?

Someone examining your project should be able to understand its structure and run it without having to ask you how every file works.

For example, your compilation command is:

```powershell
iverilog -g2005 -s riscv_run -o riscv_run riscv_alu.v riscv_single_cycle_cpu.v riscv_single_cycle_soc.v riscv_run.v
```

Then execute the simulation with:

```powershell
vvp riscv_run
```

The first command compiles the Verilog files into a simulation executable. The second runs that executable and displays the results.

---

# 8. How Everything Connects

The following is the conceptual flow of your processor:

```text
                  program.hex
                      |
                      v
          +-------------------------+
          | Instruction Memory      |
          | (256 x 32-bit words)    |
          +------------+------------+
                       |
                       v
          +-------------------------+
          |                         |
          |  Single-Cycle CPU       |
          |                         |
          |  1. Fetch instruction   |
          |  2. Decode instruction  |
          |  3. Read registers      |
          |  4. Execute operation   |
          |  5. Access data memory  |
          |  6. Write back result   |
          |                         |
          +------+------------+-----+
                 |            |
                 v            v
          +-----------+  +----------------+
          | ALU       |  | Data Memory    |
          |           |  | 256 x 32-bit   |
          +-----------+  +----------------+
                 |
                 v
          Register file
          (32 registers)
                 |
                 v
          Next instruction

          riscv_run.v
          drives the simulation
          and displays the results.
```

This is a conceptual diagram: the ALU and register file are implemented within the CPU module, while instruction and data memories are provided by the SoC module.

---

# 9. How One Instruction Travels Through the Files

Consider:

```asm
ADD x3, x1, x2
```

Suppose `x1 = 10` and `x2 = 20`.

| Step | What happens?                                               | Where?                             |
| ---- | ----------------------------------------------------------- | ---------------------------------- |
| 1    | The PC identifies the address of the instruction.           | `riscv_single_cycle_cpu.v`         |
| 2    | The machine instruction is fetched from instruction memory. | `riscv_single_cycle_soc.v` and CPU |
| 3    | The CPU decodes it as an ADD instruction.                   | `riscv_single_cycle_cpu.v`         |
| 4    | The CPU reads the values of `x1` and `x2`.                  | CPU register file                  |
| 5    | The ALU adds 10 and 20.                                     | `riscv_alu.v`                      |
| 6    | The result, 30, is selected for write-back.                 | `riscv_single_cycle_cpu.v`         |
| 7    | The result is written to `x3`.                              | CPU register file                  |
| 8    | The runner displays the register update.                    | `riscv_run.v`                      |

The machine instruction itself comes from `program.hex`, which the SoC loads into instruction memory before execution.

---

# 10. What Makes This a Single-Cycle Processor?

A **single-cycle processor** is designed so that each supported instruction completes its execution within one clock cycle.

Conceptually:

$$
\boxed{\text{One instruction} \longrightarrow \text{One clock cycle}}
$$

For example, the `ADD` instruction performs instruction fetch, decode, operand reading, arithmetic, and register write-back within its execution cycle.

This does not mean the entire program executes in one cycle. If your program has three arithmetic instructions, those instructions normally execute over three clock cycles.

Your sample program has three arithmetic instructions followed by a self-loop. The simulation output confirms that the first three instructions produce the expected register values.

**Verification status:** You have successfully compiled and run the sample program. This confirms the tested instructions and simulation flow work for that example; it does not yet establish that all 37 supported instructions have been tested.

## Final Summary

Remember these six roles:

* **`riscv_alu.v`** — Performs calculations.
* **`riscv_single_cycle_cpu.v`** — Controls instruction execution.
* **`riscv_single_cycle_soc.v`** — Provides and connects the memories.
* **`riscv_run.v`** — Starts and monitors the simulation.
* **`program.hex`** — Supplies the machine instructions to execute.
* **`README.md`** — Explains how to understand and run the project.

The key distinction is that **the CPU implements the processor's behavior, the ALU performs operations, the SoC supplies memory, and the runner makes the simulated execution observable.**