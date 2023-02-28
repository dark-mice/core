import std/[sequtils, strutils]

type ByteArray* = ref object
    bytes*: seq[int]

proc newByteArray*(): ByteArray =
    ByteArray(bytes: @[]);

proc newByteArray*(bytes: seq[int]): ByteArray =
    ByteArray(bytes: bytes);

proc toByteArray*(self: string): ByteArray =
    ByteArray(bytes: map(@self, proc(x: char): int = int(x)))

proc writeByte*(self: ByteArray, value: int) =
    self.bytes.add(value);

proc writeCC*(self: ByteArray, C: Natural, CC: Natural) =
    self.writeByte(C);
    self.writeByte(CC);

proc writeBool*(self: ByteArray, value: bool) =
    self.bytes.add(if value: 1 else: 0);

proc writeShort*(self: ByteArray, value: int) =
    self.bytes.add((value shr 8) and 0xFF);
    self.bytes.add(value and 0xFF);

proc writeInt*(self: ByteArray, value: int) =
    self.bytes.add((value shr 24) and 0xFF);
    self.bytes.add((value shr 16) and 0xFF);
    self.bytes.add((value shr 8) and 0xFF);
    self.bytes.add(value and 0xFF);

proc writeString*(self: ByteArray, value: string) =
    let value = map(@value, proc(x: char): int = int(x));
    self.writeShort(value.len());
    self.bytes = self.bytes.concat(value);

proc readByte*(self: ByteArray): int =
    let value = self.bytes[0];
    self.bytes.delete(0);
    return value;

proc readBool*(self: ByteArray): bool =
    return self.readByte() == 1

proc readShort*(self: ByteArray): int =
    return (self.readByte() shl 8) or self.readByte();

proc readInt*(self: ByteArray): int =
    return (self.readByte() shl 24) or (self.readByte() shl 16) or (self.readByte() shl 8) or self.readByte();

proc readString*(self: ByteArray): string =
    let length = self.readShort() - 1;
    let value = self.bytes[0..length];
    self.bytes = self.bytes[length + 1..self.bytes.len() - 1];
    return map(value, proc(x: int): char = char(x)).join;

proc toString*(self: ByteArray): string =
    return map(self.bytes, proc(x: int): char = char(x)).join;