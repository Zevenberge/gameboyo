module gameboyo.ascii;

ubyte[length] toPaddedBytes(size_t length)(string text) @safe pure nothrow @nogc
in(text.length <= length, "Cannot fit an overflowing text in the buffer")
{
    ubyte[length] output;
    foreach(i, ch; text)
    {
        output[i] = cast(ubyte)ch;
    }
    return output;
}

@("Is a text transformed to bytes")
@safe
unittest
{
    const text = "ABC";
    const bytes = text.toPaddedBytes!(3);
    assert(bytes == [0x41, 0x42, 0x43]);
    const padding = text.toPaddedBytes!(4);
    assert(padding[3] == 0x00);
}

string fromPaddedBytes(const ubyte[] bytes) @safe pure
{
    import std.algorithm : map, until;
    import std.conv : to;
    return bytes.until!(b => b == 0x00).map!(b => cast(char)b).to!string;
}

@("Can I parse the padded bytes")
@safe
unittest
{
    const(ubyte[3]) unpaddedBytes = [0x41, 0x42, 0x43];
    const unpaddedOutput = unpaddedBytes[].fromPaddedBytes();
    assert(unpaddedOutput == "ABC", "Could not parse unpadded output");

    const(ubyte[3]) paddedBytes = [0x41, 0x42, 0x00];
    const paddedOutput = paddedBytes[].fromPaddedBytes();
    assert(paddedOutput == "AB", "Could not parse padded output");
}