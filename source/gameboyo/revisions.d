module gameboyo.revisions;

enum Color { GameBoyColor, NotGameBoyColor }
enum Super { GameBoy, SuperGameBoy }

enum CartridgeType : ubyte {
    RomOnly               = 0x00,
    RomMbc1               = 0x01,
    RomMbc1Ram            = 0x02,
    RomMbc1RamBatt        = 0x03,
    RomMbc2               = 0x05,
    RomMbc2Battery        = 0x06,
    RomRam                = 0x08,
    RomRamBattery         = 0x09,
    RomMmmo1              = 0x0B,
    RomMmmo1Sram          = 0x0C,
    RomMmmo1SramBatt      = 0x0D,
    RomMbc3TimerBatt      = 0x0F,
    RomMbc3TimerRamBatt   = 0x10,
    RomMbc3               = 0x11,
    RomMbc3Ram            = 0x12,
    RomMbc3RamBatt        = 0x13,
    RomMbc5               = 0x19,
    RomMbc5Ram            = 0x1A,
    RomMbc5RamBatt        = 0x1B,
    RomMbc5Rumble         = 0x1C,
    RomMbc5RumbleSRam     = 0x1D,
    RomMbc5RumbleSRamBatt = 0x1E,
    PocketCamera          = 0x1F,
    BandaiTama5           = 0xFD,
    HudsonHuC3            = 0xFE,
    HudsonHuC1            = 0xFF,
}