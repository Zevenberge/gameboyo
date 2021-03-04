module gameboyo.memorymap;

/// Kilobyte
enum kB = 1024;

/// Memory layout as seen on http://fms.komkon.org/GameBoy/Tech/Software.html
struct MemoryMap
{
    ubyte[16 * kB] romBank0;
    ubyte[16 * kB] switchableRomBank;
    ubyte[ 8 * kB] vRam;
    ubyte[ 8 * kB] switchableRamBank;
    ubyte[15 * kB + 768] internalRam;
    ubyte[ 256 ] ioAndInternalRam;
}

@("Are the memory adresses mapped correctly")
@system
unittest
{
    import std.conv : to;
    import std.stdio : writeln;

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
    const ioAndInternalRam = cast(void*)map.ioAndInternalRam;
    assert(ioAndInternalRam - baseAdress == 0xFF00, "IO and internal RAM not mapped correctly");
}