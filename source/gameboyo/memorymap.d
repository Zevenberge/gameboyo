module gameboyo.memorymap;

import gameboyo.revisions;

/// Kilobyte
enum kB = 1024;

/// Memory layout as seen on http://fms.komkon.org/GameBoy/Tech/Software.html
struct MemoryMap
{
    @disable this(this);

    /// 0x0000 - 0x3FFF
    ubyte[16 * kB] romBank0; 
    /// 0x4000 - 0x7FFF
    ubyte[16 * kB] switchableRomBank;
    /// 0x8000 - 0x9FFF
    ubyte[ 8 * kB] vRam;
    /// 0xA000 - 0xBFFF
    ubyte[ 8 * kB] switchableRamBank;
    /// 0xC000 - 0xDFFF
    /// The addresses E000-FE00 appear to access the internal
    /// RAM the same as C000-DE00. (i.e. If you write a byte to
    /// address E000 it will appear at C000 and E000.
    /// Similarly, writing a byte to C000 will appear at C000
    /// and E000.)
    ubyte[ 8 * kB] internalRam;
    /// 0xE000 - 0xFDFF
    /// The addresses E000-FE00 appear to access the internal
    /// RAM the same as C000-DE00. (i.e. If you write a byte to
    /// address E000 it will appear at C000 and E000.
    /// Similarly, writing a byte to C000 will appear at C000
    /// and E000.)
    ubyte[ 8 * kB - 256] echoOfInternalRam;
    /// 0xFE00 - 0xFFFF
    ubyte[ 256 ] ioAndInternalRam;

    /// Request a byte in the memory by global index (0x0000 to 0xFFFF).
    ubyte opIndex(size_t index) @trusted pure const nothrow @nogc
    in(index <= MemoryMap.sizeof, "Requested index was out of bounds")
    {
        return (cast(ubyte*)&this)[index];
    }

    /// Ditto
    void opIndexAssign(ubyte value, size_t index) @trusted pure nothrow @nogc
    in(index <= MemoryMap.sizeof, "Requested index was out of bounds")
    {
        (cast(ubyte*)&this)[index] = value;
        if(index >= 0xE000 && index < 0xFE00)
        {
            (cast(ubyte*)&this)[index - 0x2000] = value;
        }
        else if(index >= 0xC000 && index < 0xDE00)
        {
            (cast(ubyte*)&this)[index + 0x2000] = value;
        }
    }

    /// Request a slice in the memory by global index (0x0000 to 0xFFFF).
    ubyte[] opSlice(size_t from, size_t to) @trusted pure nothrow @nogc return
    in(from <= to, "Initial index of the slice is larger than the outer index")
    in(to <= MemoryMap.sizeof, "Requested index was out of bounds")
    {
        return (cast(ubyte*)&this)[from .. to];
    }

    /// Copies the given array into the desired area. The range needs to be explicitly specified as a sanity check.
    /// Both indices are inclusive.
    void opSliceAssign(size_t length)(ubyte[length] value, size_t from, size_t to) @trusted pure nothrow @nogc
    in(to <= MemoryMap.sizeof, "Requested upper index was out of bounds")
    in(from + value.length == to + 1, "Given bounds are not correct")
    {
        // TODO: Mirror assignment?
        (cast(ubyte*)&this)[from .. to + 1] = value;
    }

    /// Gets the 16-bit value spanning two bytes starting at the
    /// requested index. Least-significant byte is first.
    ushort shortAt(size_t index) @safe pure const nothrow @nogc
    {
        return cast(ushort)this[index + 1] << 8  | this[index];
    }
}

@("Are the memory adresses mapped correctly")
@system
unittest
{
    import std.conv : to;

    static assert(MemoryMap.sizeof == (0xFFFF + 1), 
        "The memory map doesn't have the correct size, was" 
            ~ MemoryMap.sizeof.to!string ~ " but expected " ~ (0xFFFF + 1).to!string);
    const map = new MemoryMap();
    const baseAdress = cast(void*)map;
    const romBank0 = cast(void*)map.romBank0;
    assert(romBank0 - baseAdress == 0x0000, "ROM bank #0 not mapped correctly");
    const switchableRomBank = cast(void*)map.switchableRomBank;
    assert(switchableRomBank - baseAdress == 0x4000, "Switchable ROM bank not mapped correctly");
    const vRam = cast(void*)map.vRam;
    assert(vRam - baseAdress == 0x8000, "VRAM not mapped correctly");
    const switchableRamBank = cast(void*)map.switchableRamBank;
    assert(switchableRamBank - baseAdress == 0xA000, "Switchable RAM bank not mapped correctly");
    const internalRam = cast(void*)map.internalRam;
    assert(internalRam - baseAdress == 0xC000, "Internal RAM not mapped correctly");
    const echoOfInternalRam = cast(void*)map.echoOfInternalRam;
    assert(echoOfInternalRam - baseAdress == 0xE000, "Echo of internal RAM not mapped correctly");
    const ioAndInternalRam = cast(void*)map.ioAndInternalRam;
    assert(ioAndInternalRam - baseAdress == 0xFF00, "IO and internal RAM not mapped correctly");
}

@("Is the internal RAM echoed correctly")
@safe
unittest
{
    auto map = new MemoryMap();
    (*map)[0xE000] = 0xCD;
    assert((*map)[0xC000] == 0xCD, "Value not correctly echoed in the first part");
    (*map)[0xC000] = 0xAB;
    assert((*map)[0xE000] == 0xAB, "Value not correctly echoed in the latter part");
    (*map)[0xDE00] = 0xEF;
    assert((*map)[0xFE00] != 0xEF, "Valued echoed into a different part of the RAM");
    (*map)[0xFE00] = 0xFA;
    assert((*map)[0xDE00] != 0xFA, "Valued echoed from a different part of the RAM");
}

@("Can I request a 16-bit value")
@safe unittest
{
    auto map = new MemoryMap();
    (*map)[0xE000] = 0xCD;
    (*map)[0xE001] = 0xAB;
    assert(map.shortAt(0xE000) == 0xABCD, "The least-significant byte is first");
}

static immutable scrollingNintendoGraphic = [
    0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
    0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E, 0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
    0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC, 0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E
];

/// Gets the title of the ROM
string title(MemoryMap* map) @safe pure
{
    import gameboyo.ascii : fromPaddedBytes;
    return (*map)[0x0134 .. 0x0142].fromPaddedBytes();
}

@("Can I get the title of the game")
@safe
unittest
{
    import gameboyo.ascii : toPaddedBytes;

    auto memoryMap = new MemoryMap();
    (*memoryMap)[0x0134 .. 0x0142] = "POKEMON".toPaddedBytes!(15);
    auto title = memoryMap.title();
    assert(title == "POKEMON", "Could not get the title");
}

private enum GameBoyColorFlagMemoryAdress = 0x0143;
private enum GameBoyColorFlagValue = 0x80;

Color isGameBoyColor(MemoryMap* map) @safe pure nothrow @nogc
{
    return (*map)[GameBoyColorFlagMemoryAdress] == GameBoyColorFlagValue
        ? Color.GameBoyColor : Color.NotGameBoyColor;
}

@("Is GameBoyColor flag recognised")
@safe
unittest
{
    auto memoryMap = new MemoryMap();
    (*memoryMap)[0x0143] = 0x80;
    assert(memoryMap.isGameBoyColor == Color.GameBoyColor, "GameBoyColor flag not recognised");
    (*memoryMap)[0x0143] = 0x00;
    assert(memoryMap.isGameBoyColor == Color.NotGameBoyColor, "Default for the normal GameBoy not recognised");
    (*memoryMap)[0x0143] = 0xDD;
    assert(memoryMap.isGameBoyColor == Color.NotGameBoyColor, "A random value is not seen as the normal GameBoy");
}

size_t romSize(MemoryMap* map) @safe pure nothrow @nogc
{
    const flag = (*map)[0x0148];
    switch(flag)
    {
        case 0x00: return   2 * 16 * kB;
        case 0x01: return   4 * 16 * kB;
        case 0x02: return   8 * 16 * kB;
        case 0x03: return  16 * 16 * kB;
        case 0x04: return  32 * 16 * kB;
        case 0x05: return  64 * 16 * kB;
        case 0x06: return 128 * 16 * kB;
        case 0x52: return  72 * 16 * kB;
        case 0x53: return  80 * 16 * kB;
        case 0x54: return  96 * 16 * kB;
        default: assert(false, "Unknown ROM size.");
    }
}

@("Are the ROM sizes recognised")
@safe
unittest
{
    auto map = new MemoryMap();
    (*map)[0x0148] = 0x00;
    assert(map.romSize() ==   2 * 16 * kB, "Initial ROM size not seen");

    (*map)[0x0148] = 0x01;
    assert(map.romSize() ==   4 * 16 * kB, "Tiny ROM size not seen");

    (*map)[0x0148] = 0x02;
    assert(map.romSize() ==   8 * 16 * kB, "Small ROM size not seen");

    (*map)[0x0148] = 0x03;
    assert(map.romSize() ==  16 * 16 * kB, "Medium ROM size not seen");

    (*map)[0x0148] = 0x04;
    assert(map.romSize() ==  32 * 16 * kB, "Large ROM size not seen");

    (*map)[0x0148] = 0x05;
    assert(map.romSize() ==  64 * 16 * kB, "Big ROM size not seen");

    (*map)[0x0148] = 0x06;
    assert(map.romSize() == 128 * 16 * kB, "Huge ROM size not seen");

    (*map)[0x0148] = 0x52;
    assert(map.romSize() ==  72 * 16 * kB, "Weird ROM size 1 not seen");

    (*map)[0x0148] = 0x53;
    assert(map.romSize() ==  80 * 16 * kB, "Weird ROM size 2 not seen");

    (*map)[0x0148] = 0x54;
    assert(map.romSize() ==  96 * 16 * kB, "Weird ROM size 3 not seen");
}

size_t ramSize(MemoryMap* map) @safe pure nothrow @nogc
{
    const flag = (*map)[0x0149];
    switch(flag)
    {
        case 0x00: return   0 * kB;
        case 0x01: return   2 * kB;
        case 0x02: return   8 * kB;
        case 0x03: return  32 * kB;
        case 0x04: return 128 * kB;
        default: assert(false, "Unknown RAM size.");
    }
}

@("Can I get the size of the RAM")
@safe
unittest
{
    auto map = new MemoryMap();
    (*map)[0x0149] = 0x00;
    assert(map.ramSize() ==   0 * kB, "No RAM not seen");

    (*map)[0x0149] = 0x01;
    assert(map.ramSize() ==   2 * kB, "2 kB not seen");

    (*map)[0x0149] = 0x02;
    assert(map.ramSize() ==   8 * kB, "8 kB not seen");

    (*map)[0x0149] = 0x03;
    assert(map.ramSize() ==  32 * kB, "32 kB RAM not seen");

    (*map)[0x0149] = 0x04;
    assert(map.ramSize() == 128 * kB, "128 kB RAM not seen");
}