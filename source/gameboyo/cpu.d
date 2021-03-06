module gameboyo.cpu;

import gameboyo.memorymap;
import gameboyo.register;

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
            static foreach (immediateLoad; [
                    tuple("b", 0x06), tuple("c", 0x0E), tuple("d", 0x16),
                    tuple("e", 0x1E), tuple("h", 0x26), tuple("l", 0x2E),
                    tuple("a", 0x3E)
                ])
            {
        case immediateLoad[1]:
                __traits(getMember, registers.eightBit, immediateLoad[0]) = memory[registers.programCounter
                    + 1];
                registers.programCounter += 2;
                return 8;
            }

            // Load values from different registers into other registers.
            static foreach (registerLoad; [
                    tuple("a", "a", 0x7F), tuple("a", "b", 0x78),
                    tuple("a", "c", 0x79), tuple("a", "d", 0x7A),
                    tuple("a", "e", 0x7B), tuple("a", "h", 0x7C),
                    tuple("a", "l", 0x7D), tuple("b", "b", 0x40),
                    tuple("b", "c", 0x41), tuple("b", "d", 0x42),
                    tuple("b", "e", 0x43), tuple("b", "h", 0x44),
                    tuple("b", "l", 0x45), tuple("c", "b", 0x48),
                    tuple("c", "c", 0x49), tuple("c", "d", 0x4A),
                    tuple("c", "e", 0x4B), tuple("c", "h", 0x4C),
                    tuple("c", "l", 0x4D), tuple("d", "b", 0x50),
                    tuple("d", "c", 0x51), tuple("d", "d", 0x52),
                    tuple("d", "e", 0x53), tuple("d", "h", 0x54),
                    tuple("d", "l", 0x55), tuple("e", "b", 0x58),
                    tuple("e", "c", 0x59), tuple("e", "d", 0x5A),
                    tuple("e", "e", 0x5B), tuple("e", "h", 0x5C),
                    tuple("e", "l", 0x5D), tuple("h", "b", 0x60),
                    tuple("h", "c", 0x61), tuple("h", "d", 0x62),
                    tuple("h", "e", 0x63), tuple("h", "h", 0x64),
                    tuple("h", "l", 0x65), tuple("l", "b", 0x68),
                    tuple("l", "c", 0x69), tuple("l", "d", 0x6A),
                    tuple("l", "e", 0x6B), tuple("l", "h", 0x6C),
                    tuple("l", "l", 0x6D), tuple("b", "a", 0x47),
                    tuple("c", "a", 0x4F), tuple("d", "a", 0x57),
                    tuple("e", "a", 0x5F), tuple("h", "a", 0x67),
                    tuple("l", "a", 0x6F)
                ])
            {
        case registerLoad[2]:
                __traits(getMember, registers.eightBit, registerLoad[0]) = __traits(getMember,
                        registers.eightBit, registerLoad[1]);
                registers.programCounter++;
                return 4;
            }

            // Load values from pointers (HL).
            static foreach (pointerLoad; [
                    tuple("a", "hl", 0x7E), tuple("b", "hl", 0x46),
                    tuple("c", "hl", 0x4E), tuple("d", "hl", 0x56),
                    tuple("e", "hl", 0x5E), tuple("h", "hl", 0x66),
                    tuple("l", "hl", 0x6E), tuple("a", "bc", 0x0A),
                    tuple("a", "de", 0x1A)
                ])
            {
        case pointerLoad[2]:
                __traits(getMember, registers.eightBit, pointerLoad[0]) = memory[__traits(getMember,
                            registers.sixteenBit, pointerLoad[1])];
                registers.programCounter++;
                return 8;
            }

            // Load pointer (HL) into A and decrement HL.
        case 0x3A:
            registers.eightBit.a = memory[registers.sixteenBit.hl];
            registers.sixteenBit.hl--;
            registers.programCounter++;
            return 8;

            // Load pointer (HL) into A and increment HL.
        case 0x2A:
            registers.eightBit.a = memory[registers.sixteenBit.hl];
            registers.sixteenBit.hl++;
            registers.programCounter++;
            return 8;

            // Load IO/internal RAM to A given by register C
        case 0xF2:
            registers.eightBit.a = memory[0xFF00 + registers.eightBit.c];
            registers.programCounter++;
            return 8;

            // Load IO/internal RAM to A given by an immediate value
        case 0xF0:
            registers.eightBit.a = memory[0xFF00 + memory[registers.programCounter + 1]];
            registers.programCounter += 2;
            return 12;

            // Load a value given by immediate pointer (nn) to A.
        case 0xFA:
            {
                immutable pointer = memory.shortAt(registers.programCounter + 1);
                registers.eightBit.a = memory[pointer];
            }
            registers.programCounter += 3;
            return 16;

            // Write register values into the memory pointed to by (HL).
            static foreach (pointerWrite; [
                    tuple("hl", "b", 0x70), tuple("hl", "c", 0x71),
                    tuple("hl", "d", 0x72), tuple("hl", "e", 0x73),
                    tuple("hl", "h", 0x74), tuple("hl", "l", 0x75),
                    tuple("bc", "a", 0x02), tuple("de", "a", 0x12),
                    tuple("hl", "a", 0x77)
                ])
            {
        case pointerWrite[2]:
                memory[__traits(getMember, registers.sixteenBit, pointerWrite[0])] = __traits(getMember,
                        registers.eightBit, pointerWrite[1]);
                registers.programCounter++;
                return 8;
            }

            // Write A into the memory pointed to by (HL) and decrement HL.
        case 0x32:
            memory[registers.sixteenBit.hl] = registers.eightBit.a;
            registers.sixteenBit.hl--;
            registers.programCounter++;
            return 8;

            // Write A into the memory pointed to by (HL) and increment HL.
        case 0x22:
            memory[registers.sixteenBit.hl] = registers.eightBit.a;
            registers.sixteenBit.hl++;
            registers.programCounter++;
            return 8;

            // Write an immediade value n into the memory pointed to by (HL).
        case 0x36:
            memory[registers.sixteenBit.hl] = memory[registers.programCounter + 1];
            registers.programCounter += 2;
            return 12;

            // Write register A into the memory pointed to by an immediate value.
        case 0xEA:
            {
                immutable pointer = memory.shortAt(registers.programCounter + 1);
                memory[pointer] = registers.eightBit.a;
            }
            registers.programCounter += 3;
            return 16;

            // Write register A to the IO memory pointed to by (C).
        case 0xE2:
            memory[0xFF00 + registers.eightBit.c] = registers.eightBit.a;
            registers.programCounter++;
            return 8;

            // Write register A to the IO memory pointed to by an immediate value
        case 0xE0:
            memory[0xFF00 + memory[registers.programCounter + 1]] = registers.eightBit.a;
            registers.programCounter += 2;
            return 12;

            // Load a 16-bit immediate value to a sixteen bit register
            static foreach(immediate16BitLoad; [
                tuple("bc", 0x01), tuple("de", 0x11),
                tuple("hl", 0x21), tuple("sp", 0x31)
            ])
        case immediate16BitLoad[1]:
            {
                immutable value = memory.shortAt(registers.programCounter + 1);
            static if(immediate16BitLoad[0] == "sp")
                registers.stackPointer = value;
            else
                __traits(getMember, registers.sixteenBit, immediate16BitLoad[0]) = value;
            }
            registers.programCounter += 3;
            return 12;

            // Write stack pointer + n into HL
        case 0xF8:
            {
                const value = registers.stackPointer + memory[registers.programCounter + 1];
                registers.sixteenBit.hl = cast(ushort)value;
            }
            registers.programCounter += 2;
            return 12;

            // Write HL into the stack pointer
        case 0xF9:
            registers.stackPointer = registers.sixteenBit.hl;
            registers.programCounter++;
            return 8;

        default:
            assert(false, "Unknown opcode");
        }
    }
}

@("Can I load immediate 8-bit values into the registers")
@safe unittest
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

    cpu.memory[0x010C] = 0x3E;
    cpu.memory[0x010D] = 0x99;
    const ticksIntoRegisterA = cpu.executeInstruction();
    assert(ticksIntoRegisterA == 8, "Duration of the 0x3E instruction was not right");
    assert(cpu.registers.eightBit.a == 0x99, "The value should be placed in register A");
    assert(cpu.registers.programCounter == 0x010E,
            "The program counter should have advanced to 0x10E");
}

@("Can I load an 8-bit value from a different register into A")
@safe unittest
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

    cpu.memory[0x0103] = 0x7A;
    cpu.registers.eightBit.d = 0xDE;
    const ticksAD = cpu.executeInstruction();
    assert(ticksAD == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.a == 0xDE, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x7B;
    cpu.registers.eightBit.e = 0xEF;
    const ticksAE = cpu.executeInstruction();
    assert(ticksAE == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.a == 0xEF, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x7C;
    cpu.registers.eightBit.h = 0xFA;
    const ticksAH = cpu.executeInstruction();
    assert(ticksAH == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.a == 0xFA, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x7D;
    cpu.registers.eightBit.l = 0x96;
    const ticksAL = cpu.executeInstruction();
    assert(ticksAL == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.a == 0x96, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a different register into B")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x40;
    cpu.registers.eightBit.b = 0xAB;
    const ticksBB = cpu.executeInstruction();
    assert(ticksBB == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.b == 0xAB, "The value of the register B should be unchanged");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x41;
    cpu.registers.eightBit.c = 0xBA;
    const ticksBC = cpu.executeInstruction();
    assert(ticksBC == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.b == 0xBA, "The value of the register B should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x42;
    cpu.registers.eightBit.d = 0xCA;
    const ticksBD = cpu.executeInstruction();
    assert(ticksBD == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.b == 0xCA, "The value of the register B should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x43;
    cpu.registers.eightBit.e = 0xDE;
    const ticksBE = cpu.executeInstruction();
    assert(ticksBE == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.b == 0xDE, "The value of the register B should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x44;
    cpu.registers.eightBit.h = 0xEF;
    const ticksBH = cpu.executeInstruction();
    assert(ticksBH == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.b == 0xEF, "The value of the register B should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x45;
    cpu.registers.eightBit.l = 0xFA;
    const ticksBL = cpu.executeInstruction();
    assert(ticksBL == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.b == 0xFA, "The value of the register B should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x47;
    cpu.registers.eightBit.a = 0x66;
    const ticksBA = cpu.executeInstruction();
    assert(ticksBA == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.b == 0x66, "The value of the register B should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a different register into C")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x48;
    cpu.registers.eightBit.b = 0xAB;
    const ticksCB = cpu.executeInstruction();
    assert(ticksCB == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.c == 0xAB, "The value of the register C should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x49;
    cpu.registers.eightBit.c = 0xBA;
    const ticksCC = cpu.executeInstruction();
    assert(ticksCC == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.c == 0xBA, "The value of the register C should be unchanged");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x4A;
    cpu.registers.eightBit.d = 0xCA;
    const ticksCD = cpu.executeInstruction();
    assert(ticksCD == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.c == 0xCA, "The value of the register C should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x4B;
    cpu.registers.eightBit.e = 0xDE;
    const ticksCE = cpu.executeInstruction();
    assert(ticksCE == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.c == 0xDE, "The value of the register C should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x4C;
    cpu.registers.eightBit.h = 0xEF;
    const ticksCH = cpu.executeInstruction();
    assert(ticksCH == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.c == 0xEF, "The value of the register C should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x4D;
    cpu.registers.eightBit.l = 0xFA;
    const ticksCL = cpu.executeInstruction();
    assert(ticksCL == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.c == 0xFA, "The value of the register C should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x4F;
    cpu.registers.eightBit.a = 0x66;
    const ticksCA = cpu.executeInstruction();
    assert(ticksCA == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.c == 0x66, "The value of the register C should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a different register into D")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x50;
    cpu.registers.eightBit.b = 0xAB;
    const ticksDB = cpu.executeInstruction();
    assert(ticksDB == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.d == 0xAB, "The value of the register D should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x51;
    cpu.registers.eightBit.c = 0xBA;
    const ticksDC = cpu.executeInstruction();
    assert(ticksDC == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.d == 0xBA, "The value of the register D should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x52;
    cpu.registers.eightBit.d = 0xCA;
    const ticksDD = cpu.executeInstruction();
    assert(ticksDD == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.d == 0xCA, "The value of the register D should be unchanged");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x53;
    cpu.registers.eightBit.e = 0xDE;
    const ticksDE = cpu.executeInstruction();
    assert(ticksDE == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.d == 0xDE, "The value of the register D should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x54;
    cpu.registers.eightBit.h = 0xEF;
    const ticksDH = cpu.executeInstruction();
    assert(ticksDH == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.d == 0xEF, "The value of the register D should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x55;
    cpu.registers.eightBit.l = 0xFA;
    const ticksDL = cpu.executeInstruction();
    assert(ticksDL == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.d == 0xFA, "The value of the register D should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x57;
    cpu.registers.eightBit.a = 0x66;
    const ticksDA = cpu.executeInstruction();
    assert(ticksDA == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.d == 0x66, "The value of the register D should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a different register into E")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x58;
    cpu.registers.eightBit.b = 0xAB;
    const ticksEB = cpu.executeInstruction();
    assert(ticksEB == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.e == 0xAB, "The value of the register E should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x59;
    cpu.registers.eightBit.c = 0xBA;
    const ticksEC = cpu.executeInstruction();
    assert(ticksEC == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.e == 0xBA, "The value of the register E should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x5A;
    cpu.registers.eightBit.d = 0xCA;
    const ticksED = cpu.executeInstruction();
    assert(ticksED == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.e == 0xCA, "The value of the register E should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x5B;
    cpu.registers.eightBit.e = 0xDE;
    const ticksEE = cpu.executeInstruction();
    assert(ticksEE == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.e == 0xDE, "The value of the register E should be unchanged");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x5C;
    cpu.registers.eightBit.h = 0xEF;
    const ticksEH = cpu.executeInstruction();
    assert(ticksEH == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.e == 0xEF, "The value of the register E should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x5D;
    cpu.registers.eightBit.l = 0xFA;
    const ticksEL = cpu.executeInstruction();
    assert(ticksEL == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.e == 0xFA, "The value of the register E should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x5F;
    cpu.registers.eightBit.a = 0x66;
    const ticksEA = cpu.executeInstruction();
    assert(ticksEA == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.e == 0x66, "The value of the register E should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a different register into H")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x60;
    cpu.registers.eightBit.b = 0xAB;
    const ticksHB = cpu.executeInstruction();
    assert(ticksHB == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.h == 0xAB, "The value of the register H should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x61;
    cpu.registers.eightBit.c = 0xBA;
    const ticksHC = cpu.executeInstruction();
    assert(ticksHC == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.h == 0xBA, "The value of the register H should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x62;
    cpu.registers.eightBit.d = 0xCA;
    const ticksHD = cpu.executeInstruction();
    assert(ticksHD == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.h == 0xCA, "The value of the register H should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x63;
    cpu.registers.eightBit.e = 0xDE;
    const ticksHE = cpu.executeInstruction();
    assert(ticksHE == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.h == 0xDE, "The value of the register H should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x64;
    cpu.registers.eightBit.h = 0xEF;
    const ticksHH = cpu.executeInstruction();
    assert(ticksHH == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.h == 0xEF, "The value of the register H should be unchanged");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x65;
    cpu.registers.eightBit.l = 0xFA;
    const ticksHL = cpu.executeInstruction();
    assert(ticksHL == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.h == 0xFA, "The value of the register H should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x67;
    cpu.registers.eightBit.a = 0x66;
    const ticksHA = cpu.executeInstruction();
    assert(ticksHA == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.h == 0x66, "The value of the register H should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a different register into L")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x68;
    cpu.registers.eightBit.b = 0xAB;
    const ticksLB = cpu.executeInstruction();
    assert(ticksLB == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.l == 0xAB, "The value of the register L should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x69;
    cpu.registers.eightBit.c = 0xBA;
    const ticksLC = cpu.executeInstruction();
    assert(ticksLC == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.l == 0xBA, "The value of the register L should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x6A;
    cpu.registers.eightBit.d = 0xCA;
    const ticksLD = cpu.executeInstruction();
    assert(ticksLD == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.l == 0xCA, "The value of the register L should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x6B;
    cpu.registers.eightBit.e = 0xDE;
    const ticksLE = cpu.executeInstruction();
    assert(ticksLE == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.l == 0xDE, "The value of the register L should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x6C;
    cpu.registers.eightBit.h = 0xEF;
    const ticksLH = cpu.executeInstruction();
    assert(ticksLH == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.l == 0xEF, "The value of the register L should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x6D;
    cpu.registers.eightBit.l = 0xFA;
    const ticksLL = cpu.executeInstruction();
    assert(ticksLL == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.l == 0xFA, "The value of the register L should be unchanged");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x6F;
    cpu.registers.eightBit.a = 0x66;
    const ticksLA = cpu.executeInstruction();
    assert(ticksLA == 4, "A register to register operation takes 4 ticks");
    assert(cpu.registers.eightBit.l == 0x66, "The value of the register L should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a pointer in HL")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x7E;
    cpu.memory[0xABCD] = 0xDD;
    cpu.registers.sixteenBit.hl = 0xABCD;
    const ticksAHL = cpu.executeInstruction();
    assert(ticksAHL == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.a == 0xDD, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x46;
    cpu.memory[0xACDC] = 0xCC;
    cpu.registers.sixteenBit.hl = 0xACDC;
    const ticksBHL = cpu.executeInstruction();
    assert(ticksBHL == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.b == 0xCC, "The value of the register B should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x4E;
    cpu.memory[0xBEEF] = 0x99;
    cpu.registers.sixteenBit.hl = 0xBEEF;
    const ticksCHL = cpu.executeInstruction();
    assert(ticksCHL == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.c == 0x99, "The value of the register C should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x56;
    cpu.memory[0xDEAD] = 0x99;
    cpu.registers.sixteenBit.hl = 0xDEAD;
    const ticksDHL = cpu.executeInstruction();
    assert(ticksDHL == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.d == 0x99, "The value of the register D should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x5E;
    cpu.memory[0xFEED] = 0x11;
    cpu.registers.sixteenBit.hl = 0xFEED;
    const ticksEHL = cpu.executeInstruction();
    assert(ticksEHL == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.e == 0x11, "The value of the register E should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x66;
    cpu.memory[0xBABE] = 0x07;
    cpu.registers.sixteenBit.hl = 0xBABE;
    const ticksHHL = cpu.executeInstruction();
    assert(ticksHHL == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.h == 0x07, "The value of the register H should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");

    cpu.memory[0x0106] = 0x6E;
    cpu.memory[0x9001] = 0x70;
    cpu.registers.sixteenBit.hl = 0x9001;
    const ticksLHL = cpu.executeInstruction();
    assert(ticksLHL == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.l == 0x70, "The value of the register L should be changed");
    assert(cpu.registers.programCounter == 0x0107,
            "The program counter should have advanced one step");
}

@("Can I load an 8-bit value from a pointer to A")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x0A;
    cpu.memory[0xABCD] = 0xDD;
    cpu.registers.sixteenBit.bc = 0xABCD;
    const ticksABC = cpu.executeInstruction();
    assert(ticksABC == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.a == 0xDD, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x1A;
    cpu.memory[0x1234] = 0xFF;
    cpu.registers.sixteenBit.de = 0x1234;
    const ticksADE = cpu.executeInstruction();
    assert(ticksADE == 8, "A pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.a == 0xFF, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");
}

@("Can I load a value given by an immediate pointer into A")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0xFA;
    cpu.memory[0x0101] = 0xCD;
    cpu.memory[0x0102] = 0xAB;
    cpu.memory[0xABCD] = 0xDD;
    const ticksABC = cpu.executeInstruction();
    assert(ticksABC == 16, "An immediate pointer to register operation takes 8 ticks");
    assert(cpu.registers.eightBit.a == 0xDD, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced three steps");
}

@("Can I put a register value into a memory location")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x70;
    cpu.registers.eightBit.b = 0xDD;
    cpu.registers.sixteenBit.hl = 0xABCD;
    const ticksHLB = cpu.executeInstruction();
    assert(ticksHLB == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xABCD] == 0xDD, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x71;
    cpu.registers.eightBit.c = 0xBA;
    cpu.registers.sixteenBit.hl = 0xDEAF;
    const ticksHLC = cpu.executeInstruction();
    assert(ticksHLC == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xDEAF] == 0xBA, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x72;
    cpu.registers.eightBit.d = 0xAF;
    cpu.registers.sixteenBit.hl = 0xF00D;
    const ticksHLD = cpu.executeInstruction();
    assert(ticksHLD == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xF00D] == 0xAF, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

    cpu.memory[0x0103] = 0x73;
    cpu.registers.eightBit.e = 0xFB;
    cpu.registers.sixteenBit.hl = 0xADDE;
    const ticksHLE = cpu.executeInstruction();
    assert(ticksHLE == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xADDE] == 0xFB, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0104,
            "The program counter should have advanced one step");

    cpu.memory[0x0104] = 0x74;
    cpu.registers.sixteenBit.hl = 0xBAED;
    const ticksHLH = cpu.executeInstruction();
    assert(ticksHLH == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xBAED] == 0xBA, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0105,
            "The program counter should have advanced one step");

    cpu.memory[0x0105] = 0x75;
    cpu.registers.sixteenBit.hl = 0xABBA;
    const ticksHLL = cpu.executeInstruction();
    assert(ticksHLL == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xABBA] == 0xBA, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced one step");
}

@("Can I put register A into a memory location")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x02;
    cpu.registers.eightBit.a = 0xDD;
    cpu.registers.sixteenBit.bc = 0xABCD;
    const ticksBCA = cpu.executeInstruction();
    assert(ticksBCA == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xABCD] == 0xDD, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0x12;
    cpu.registers.eightBit.a = 0xBA;
    cpu.registers.sixteenBit.de = 0xDEAF;
    const ticksDEA = cpu.executeInstruction();
    assert(ticksDEA == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xDEAF] == 0xBA, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced one step");

    cpu.memory[0x0102] = 0x77;
    cpu.registers.eightBit.a = 0xAF;
    cpu.registers.sixteenBit.hl = 0xF00D;
    const ticksHLA = cpu.executeInstruction();
    assert(ticksHLA == 8, "A register to pointer operation takes 8 ticks");
    assert(cpu.memory[0xF00D] == 0xAF, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced one step");

}

@("Can I put register A into a memory location given by an immediate pointer")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0xEA;
    cpu.memory[0x0101] = 0xCD;
    cpu.memory[0x0102] = 0xAB;
    cpu.registers.eightBit.a = 0xDD;
    const ticks = cpu.executeInstruction();
    assert(ticks == 16, "A register to immediate pointer operation takes 16 ticks");
    assert(cpu.memory[0xABCD] == 0xDD, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced three steps");
}

@("Can I put an immediate value into a memory location")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x36;
    cpu.memory[0x0101] = 0xDD;
    cpu.registers.sixteenBit.hl = 0xABCD;
    const ticks = cpu.executeInstruction();
    assert(ticks == 12, "An immediate value to pointer operation takes 12 ticks");
    assert(cpu.memory[0xABCD] == 0xDD, "The value of the pointed to memory should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced two steps");
}

@("Can I load IO and internal RAM into register A")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0xF2;
    cpu.registers.eightBit.c = 0xBE;
    cpu.memory[0xFFBE] = 0xAB;
    const ticksAC = cpu.executeInstruction();
    assert(ticksAC == 8, "A quirky pointer look-up takes 8 cycles");
    assert(cpu.registers.eightBit.a == 0xAB, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0xF0;
    cpu.memory[0x0102] = 0xAB;
    cpu.memory[0xFFAB] = 0xCD;
    const ticksAN = cpu.executeInstruction();
    assert(ticksAN == 12, "Putting an immediate IO pointer to register A takes 12 cycles");
    assert(cpu.registers.eightBit.a == 0xCD, "The value of the register A should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced two steps");
}

@("Can I write A to IO and Internal RAM")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0xE2;
    cpu.registers.eightBit.c = 0xBE;
    cpu.registers.eightBit.a = 0xAB;
    const ticksCA = cpu.executeInstruction();
    assert(ticksCA == 8, "A quirky pointer look-up takes 8 cycles");
    assert(cpu.memory[0xFFBE] == 0xAB, "The value of the memory location should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");

    cpu.memory[0x0101] = 0xE0;
    cpu.memory[0x0102] = 0xAA;
    cpu.registers.eightBit.a = 0xCD;
    const ticksNA = cpu.executeInstruction();
    assert(ticksNA == 12, "An immediate IO pointer look-up takes 12 cycles");
    assert(cpu.memory[0xFFAA] == 0xCD, "The value of the memory location should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced two steps");
}

@("Can I load a pointed value into A and decrement the pointer")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x3A;
    cpu.registers.sixteenBit.hl = 0xFFBE;
    cpu.memory[0xFFBE] = 0xAB;
    const ticks = cpu.executeInstruction();
    assert(ticks == 8, "The operation takes 8 cycles");
    assert(cpu.registers.eightBit.a == 0xAB, "The value of register A should be changed");
    assert(cpu.registers.sixteenBit.hl == 0xFFBD, "The HL pointer should have been decremented");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");
}

@("Can I put A into a pointed location and decrement the pointer")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x32;
    cpu.registers.sixteenBit.hl = 0xFFBE;
    cpu.registers.eightBit.a = 0xAB;
    const ticks = cpu.executeInstruction();
    assert(ticks == 8, "The operation takes 8 cycles");
    assert(cpu.memory[0xFFBE] == 0xAB, "The value of the pointed to location should be changed");
    assert(cpu.registers.sixteenBit.hl == 0xFFBD, "The HL pointer should have been decremented");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");
}

@("Can I load a pointed value into A and increment the pointer")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x2A;
    cpu.registers.sixteenBit.hl = 0xFFBE;
    cpu.memory[0xFFBE] = 0xAB;
    const ticks = cpu.executeInstruction();
    assert(ticks == 8, "The operation takes 8 cycles");
    assert(cpu.registers.eightBit.a == 0xAB, "The value of register A should be changed");
    assert(cpu.registers.sixteenBit.hl == 0xFFBF, "The HL pointer should have been incremented");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");
}

@("Can I put A into a pointed location and increment the pointer")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x22;
    cpu.registers.sixteenBit.hl = 0xFFBE;
    cpu.registers.eightBit.a = 0xAB;
    const ticks = cpu.executeInstruction();
    assert(ticks == 8, "The operation takes 8 cycles");
    assert(cpu.memory[0xFFBE] == 0xAB, "The value of the pointed to location should be changed");
    assert(cpu.registers.sixteenBit.hl == 0xFFBF, "The HL pointer should have been incremented");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");
}

@("Can I load 16-bit immediate values")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0x01;
    cpu.memory[0x0101] = 0xCD;
    cpu.memory[0x0102] = 0xAB;
    const ticksBCnn = cpu.executeInstruction();
    assert(ticksBCnn == 12, "The operation takes 12 cycles");
    assert(cpu.registers.sixteenBit.bc == 0xABCD, "The value of the register should be changed");
    assert(cpu.registers.programCounter == 0x0103,
            "The program counter should have advanced three steps");

    cpu.memory[0x0103] = 0x11;
    cpu.memory[0x0104] = 0x34;
    cpu.memory[0x0105] = 0x12;
    const ticksDEnn = cpu.executeInstruction();
    assert(ticksDEnn == 12, "The operation takes 12 cycles");
    assert(cpu.registers.sixteenBit.de == 0x1234, "The value of the register should be changed");
    assert(cpu.registers.programCounter == 0x0106,
            "The program counter should have advanced three steps");

    cpu.memory[0x0106] = 0x21;
    cpu.memory[0x0107] = 0x99;
    cpu.memory[0x0108] = 0x66;
    const ticksHLnn = cpu.executeInstruction();
    assert(ticksHLnn == 12, "The operation takes 12 cycles");
    assert(cpu.registers.sixteenBit.hl == 0x6699, "The value of the register should be changed");
    assert(cpu.registers.programCounter == 0x0109,
            "The program counter should have advanced three steps");

    cpu.memory[0x0109] = 0x31;
    cpu.memory[0x010A] = 0x88;
    cpu.memory[0x010B] = 0x77;
    const ticksSPnn = cpu.executeInstruction();
    assert(ticksSPnn == 12, "The operation takes 12 cycles");
    assert(cpu.registers.stackPointer == 0x7788, "The value of the stack pointer should be changed");
    assert(cpu.registers.programCounter == 0x010C,
            "The program counter should have advanced three steps");
}

@("Can I put HL into the stack pointer")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0xF9;
    cpu.registers.sixteenBit.hl = 0xABCD;
    const ticks = cpu.executeInstruction();
    assert(ticks == 8, "The operation takes 8 cycles");
    assert(cpu.registers.stackPointer == 0xABCD, "The value of the stack pointer should be changed");
    assert(cpu.registers.programCounter == 0x0101,
            "The program counter should have advanced one step");
}

@("Can I put a stack pointer with offset into HL")
@safe unittest
{
    Cpu* cpu = new Cpu();
    cpu.memory[0x0100] = 0xF8;
    cpu.memory[0x0101] = 0x22;
    cpu.registers.stackPointer = 0xABCD;
    const ticks = cpu.executeInstruction();
    assert(ticks == 12, "The operation takes 12 cycles");
    assert(cpu.registers.sixteenBit.hl == 0xABEF, "The value of the register should be changed");
    assert(cpu.registers.programCounter == 0x0102,
            "The program counter should have advanced two steps");
}