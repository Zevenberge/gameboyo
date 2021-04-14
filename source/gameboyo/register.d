module gameboyo.register;

private struct EightBitRegisters
{
    FlagRegister f;
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
    /// nibble in the last math operation.
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

    /// Adds two numbers and sets the corresponding flags based
    /// on the result of the operation. Returns the resulting byte.
    ubyte add(ubyte first, ubyte second) pure @nogc nothrow @safe
    {
        const result = cast(ubyte)(first + second);

        this.eightBit.f.subtract = false;
        this.eightBit.f.zero = result == 0;

        // A whole carry is performed if the 7th byte of both the first and the
        // second are equal to 1.
        this.eightBit.f.carry = (first & second & 0b1000_0000) != 0;

        // A half carry was performed if the last four bytes of the result are less than
        // either one of the input's.
        this.eightBit.f.halfCarry = lastFourBytes(first) > lastFourBytes(result);
        return result;
    }
}

@("Are the registers paired correctly")
@safe unittest
{
    auto registers = Registers();
    registers.eightBit.a = 0x01;
    registers.eightBit.f.carry = true;
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

@("Does the add function add two numbers")
@safe unittest
{
    auto registers = Registers();
    assert(registers.add(12, 34) == 46, "Numbers should have been added");
}

@("Does the add function add two numbers that overflow the ubyte")
@safe unittest
{
    auto registers = Registers();
    assert(registers.add(212, 134) == 90, "The overflow should be forgotten");
}

@("Is the substract flag reset after an add")
@safe unittest
{
    auto registers = Registers();
    registers.eightBit.f.subtract = true;
    registers.add(12, 34);
    assert(registers.eightBit.f.subtract == false, "The substractN flag should be cleared.");
}

@("Is the half-carry flag set properly")
@safe unittest
{
    auto registers = Registers();
    registers.add(0b0000_1000, 0b0000_1000);
    assert(registers.eightBit.f.halfCarry == true, 
        "A carry was performed to bit 4, so the half-carry flag should be set.");

    registers.add(0b0000_1000, 0b0000_0111);
    assert(registers.eightBit.f.halfCarry == false, 
        "A carry was not performed to bit 4, so the half-carry flag should be cleared.");
}

@("Is the carry flag set properly")
@safe unittest
{
    auto registers = Registers();
    registers.add(0b1000_0000, 0b1000_0000);
    assert(registers.eightBit.f.carry == true, 
        "A carry was performed, so the carry flag should be set.");

    registers.add(0b1000_0000, 0b0111_0000);
    assert(registers.eightBit.f.carry == false, 
        "No carry was performed, so the carry flag should be cleared.");
}

@("Is the zero flag set properly")
@safe unittest
{
    auto registers = Registers();
    registers.add(0b1000_0000, 0b1000_0000);
    assert(registers.eightBit.f.zero == true, 
        "The resulting byte is zero, so the zero flag should be set.");

    registers.add(0b1000_0000, 0b0111_0000);
    assert(registers.eightBit.f.zero == false, 
        "The result is not zero, so the zero flag should be cleared.");
}

private ubyte lastFourBytes(const ubyte b) pure @nogc nothrow @safe
{
    return b & 0b_1111;
}