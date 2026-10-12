#!/usr/bin/env python3
"""Writes a small tape for the tests: a BASIC program that starts by itself.

  make-tape.py <tape to write (.tap)>

The tests need something to load that this repository may contain, and no
game is that. This writes a tape image with one BASIC program, as SAVE "test"
LINE 10 would have made it:

  10 BORDER 1: PAPER 6: CLS : PRINT "CHIMERA TAPE TEST"
  20 LET k$=INKEY$: IF k$<>"" THEN PRINT k$;
  25 LET j=IN 31: IF j>0 AND j<32 THEN PRINT j;
  30 GO TO 20

It paints the screen, says what it is, and prints every key it sees and what
a Kempston joystick says (port 31: 1 right, 2 left, 4 down, 8 up, 16 fire),
so a run with keys or the joystick pressed ends with another screen and other
memory than a run without. With no Kempston interface the port reads 255,
which is not printed. A .tap file is a list of blocks, each a two-byte length and then the
bytes a tape recorder would play: a flag (0 for a header, 255 for data), the
contents, and a checksum.
"""
import struct
import sys

BORDER, PAPER, CLS, PRINT, LET, INKEY, IF, THEN, GO_TO, NOT_EQUAL = 0xE7, 0xDA, 0xFB, 0xF5, 0xF1, 0xA6, 0xFA, 0xCB, 0xEC, 0xC9
IN, AND = 0xBF, 0xC6


def number(n):
    """A number in a BASIC line: its digits, then the value the ROM uses."""
    return str(n).encode() + bytes([0x0E, 0, 0, n & 0xFF, n >> 8, 0])


def line(n, body):
    body = bytes(body) + b"\r"
    return struct.pack(">H", n) + struct.pack("<H", len(body)) + body


def block(flag, data):
    payload = bytes([flag]) + data
    check = 0
    for b in payload:
        check ^= b
    payload += bytes([check])
    return struct.pack("<H", len(payload)) + payload


def main():
    program = b"".join([
        line(10, bytes([BORDER]) + number(1) + b":" + bytes([PAPER]) + number(6) + b":" + bytes([CLS]) + b":" +
             bytes([PRINT]) + b'"CHIMERA TAPE TEST"'),
        line(20, bytes([LET]) + b"k$=" + bytes([INKEY]) + b":" + bytes([IF]) + b"k$" + bytes([NOT_EQUAL]) + b'""' +
             bytes([THEN, PRINT]) + b"k$;"),
        line(25, bytes([LET]) + b"j=" + bytes([IN]) + number(31) + b":" + bytes([IF]) + b"j>" + number(0) +
             bytes([AND]) + b"j<" + number(32) + bytes([THEN, PRINT]) + b"j;"),
        line(30, bytes([GO_TO]) + number(20)),
    ])
    # a header: type 0 (a program), ten characters of name, the length, the
    # line to start at, and where the variables begin (after the program)
    header = bytes([0]) + b"test".ljust(10) + struct.pack("<HHH", len(program), 10, len(program))
    with open(sys.argv[1], "wb") as out:
        out.write(block(0x00, header))
        out.write(block(0xFF, program))


if __name__ == "__main__":
    main()
