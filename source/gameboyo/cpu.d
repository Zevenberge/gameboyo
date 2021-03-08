module gameboyo.cpu;

import gameboyo.memorymap;

private struct EightBitRegisters
{
    ubyte f;
    ubyte a;

    ubyte c;
    ubyte b;

    ubyte e;
    ubyte d;

    ubyte l;
    ubyte h;
}

private struct SixteenBitRegisters
{
    ushort af;
    ushort bc;
    ushort de;
    ushort hl;
}

private struct FlagRegister
{
    @disable this(this);

    import std.bitmanip : bitfields;

    mixin(bitfields!(uint, "_", 4, bool, "carryFlagC", 1, bool,
            "halfCarryFlagH", 1, bool, "subtractFlagN", 1, bool, "zeroFlagZ", 1));

    /// Zero Flag (Z):
    /// This bit is set when the result of a math operation
    /// is zero or two values match when using the CP
    /// instruction.
    alias zero = zeroFlagZ;

    /// Subtract Flag (N):
    /// This bit is set if a subtraction was performed in the
    /// last math instruction.
    alias subtract = subtractFlagN;

    /// Half Carry Flag (H):
    /// This bit is set if a carry occurred from the lower
    // nibble in the last math operation.
    alias halfCarry = halfCarryFlagH;

    /// Carry Flag (C):
    /// This bit is set if a carry occurred from the last
    /// math operation or if register A is the smaller value
    /// when executing the CP instruction.
    alias carry = carryFlagC;
}

@("Are the flags correctly set")
@safe unittest
{
    static assert(FlagRegister.sizeof == 1, "The flag register should only be one byte");

    union U
    {
        ubyte value;
        FlagRegister flags;
    }

    U u = {value: 0x00};
    u.flags.zeroFlagZ = true;
    assert(u.value == 0b1000_0000, "The zero bit is the most significant bit");
    u.flags.zeroFlagZ = false;
    u.flags.subtractFlagN = true;
    assert(u.value == 0b0100_0000, "The subtract bit is the all but one most significant bit");
    u.flags.subtractFlagN = false;
    u.flags.halfCarryFlagH = true;
    assert(u.value == 0b0010_0000,
            "The half carry flag bit is the all but two most significant bit");
    u.flags.halfCarryFlagH = false;
    u.flags.carryFlagC = true;
    assert(u.value == 0b0001_0000, "The carry flag bit is the least significant bit");
}

struct Registers
{
    @disable this(this);

    union
    {
        /// The GameBoy has eight 8-bit registers A,B,C,D,E,F,H,L.
        /// The F register is indirectly accessible by the
        /// programmer and is used to store the results of various
        /// math operations.
        EightBitRegisters eightBit;
        /// Some instructions, however, allow you to use the
        /// registers A,B,C,D,E,H, & L as 16-bit registers by
        /// pairing them up in the following manner: AF,BC,DE
        SixteenBitRegisters sixteenBit;
    }
    /// The SP, or Stack Pointer, register
    /// points to the current stack position.
    /// As information is put onto the stack, the stack grows
    /// downward in RAM memory. As a result, the Stack Pointer
    /// should always be initialized at the highest location of
    /// RAM space that has been allocated for use by the stack.
    ushort stackPointer = 0xFFFE;

    /// The PC, or Program Counter, register
    /// points to the next instruction to be executed in the
    /// Game Boy memory. On power up, the GameBoy Program Counter is
    /// initialized to 0x0100 and the instruction found
    /// at this location in ROM is executed.
    ushort programCounter = 0x0100;
}

@("Are the registers paired correctly")
@safe unittest
{
    auto registers = Registers();
    registers.eightBit.a = 0x01;
    registers.eightBit.f = 0x10;
    assert(registers.sixteenBit.af == 0x0110, "A should be paired with F");

    registers.eightBit.b = 0x11;
    registers.eightBit.c = 0x10;
    assert(registers.sixteenBit.bc == 0x1110, "B should be paired with C");

    registers.eightBit.d = 0x10;
    registers.eightBit.e = 0x11;
    assert(registers.sixteenBit.de == 0x1011, "D should be paired with E");

    registers.eightBit.h = 0x10;
    registers.eightBit.l = 0x01;
    assert(registers.sixteenBit.hl == 0x1001, "H should be paired with L");
}

@("Is the program counter initialised correctly")
@safe unittest
{
    const registers = Registers();
    assert(registers.programCounter == 0x0100,
            "The program counter should be initialised to 0x0100.");
}

@("Is the stack pointer initialised correctly")
@safe unittest
{
    const registers = Registers();
    assert(registers.stackPointer == 0xFFFE, "The stack pointer should be initialised to 0xFFFE.");
}

/// An opcode interpreter that mimics the Gameboy's Z80 CPU.
struct Cpu
{
    @disable this(this);

    Registers registers;
    MemoryMap memory;

    /// Executes the single instruction pointd to by the program counter.
    /// Returns the amount of cycles that the operation took.
    ubyte executeInstruction() pure @nogc nothrow @safe
    {
        const opCode = memory[registers.programCounter];
        switch (opCode)
        {
            import std.typecons : tuple;

            // Load 8-bit immediate values.
            static foreach (immediateLoad; [tuple("b", 0x06), tuple("c", 0x0E), 
                tuple("d", 0x16), tuple("e", 0x1E), tuple("h", 0x26), tuple("l", 0x2E)])
            {
            case immediateLoad[1]:
                __traits(getMember, registers.eightBit, immediateLoad[0]) = memory[registers.programCounter + 1];
                registers.programCounter += 2;
                return 8;
            }

            // Load values from different registers.
            static foreach (registerLoad; [tuple("a", "a", 0x7F), tuple("a", "b", 0x78), tuple("a", "c", 0x79)])
            {
            case registerLoad[2]:
                __traits(getMember, registers.eightBit, registerLoad[0]) = 
                    __traits(getMember, registers.eightBit, registerLoad[1]);
                registers.programCounter++;
                return 4;
            }

            default:
                assert(false, "Unknown opcode");
        }
    }
}

@("Can I load immediate 8-bit values into the registers")
@safe
unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x06;
    cpu.memory[0x0101] = 0xAB;
    const ticksIntoRegisterB = cpu.executeInstruction();
    assert(ticksIntoRegisterB == 8, "Duration of the 0x06 instruction was not right");
    assert(cpu.registers.eightBit.b == 0xAB, "The value should be placed in register B");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced to 0x102");

    cpu.memory[0x0102] = 0x0E;
    cpu.memory[0x0103] = 0x12;
    const ticksIntoRegisterC = cpu.executeInstruction();
    assert(ticksIntoRegisterC == 8, "Duration of the 0x0E instruction was not right");
    assert(cpu.registers.eightBit.c == 0x12, "The value should be placed in register C");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced to 0x104");

    cpu.memory[0x0104] = 0x16;
    cpu.memory[0x0105] = 0x96;
    const ticksIntoRegisterD = cpu.executeInstruction();
    assert(ticksIntoRegisterD == 8, "Duration of the 0x16 instruction was not right");
    assert(cpu.registers.eightBit.d == 0x96, "The value should be placed in register D");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced to 0x106");

    cpu.memory[0x0106] = 0x1E;
    cpu.memory[0x0107] = 0x42;
    const ticksIntoRegisterE = cpu.executeInstruction();
    assert(ticksIntoRegisterE == 8, "Duration of the 0x1E instruction was not right");
    assert(cpu.registers.eightBit.e == 0x42, "The value should be placed in register E");
    assert(cpu.registers.programCounter == 0x0108,
            "The program counter should have advanced to 0x108");

    cpu.memory[0x0108] = 0x26;
    cpu.memory[0x0109] = 0xAF;
    const ticksIntoRegisterH = cpu.executeInstruction();
    assert(ticksIntoRegisterH == 8, "Duration of the 0x26 instruction was not right");
    assert(cpu.registers.eightBit.h == 0xAF, "The value should be placed in register H");
    assert(cpu.registers.programCounter == 0x010A,
            "The program counter should have advanced to 0x10A");

    cpu.memory[0x010A] = 0x2E;
    cpu.memory[0x010B] = 0xDD;
    const ticksIntoRegisterL = cpu.executeInstruction();
    assert(ticksIntoRegisterL == 8, "Duration of the 0x2E instruction was not right");
    assert(cpu.registers.eightBit.l == 0xDD, "The value should be placed in register L");
    assert(cpu.registers.programCounter == 0x010C,
            "The program counter should have advanced to 0x10C");
}

@("Can I load an 8-bit value from a different register")
@safe
unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x7F;
    cpu.registers.eightBit.a = 0xAB;
    const ticksAA = cpu.executeInstruction();
    assert(ticksAA == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.a == 0xAB, "The value of the register A should be unchanged");
    assert(cpu.registers.programCounter == 0x0101, 
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x78;
    cpu.registers.eightBit.b = 0xBA;
    const ticksAB = cpu.executeInstruction();
    assert(ticksAB == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.a == 0xBA, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0102, 
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x79;
    cpu.registers.eightBit.c = 0xCA;
    const ticksAC = cpu.executeInstruction();
    assert(ticksAC == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.a == 0xCA, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0103, 
            "The program counter should have advanced one step");
}