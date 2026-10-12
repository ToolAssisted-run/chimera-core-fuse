#!/usr/bin/env python3
"""Writes the buttons of a test movie, in one of two forms.

  make-movie.py <frames>               the movie as Chimera's engine reads and
                                       writes it: a row a frame; between bars,
                                       43 columns for the keyboard, the tape's
                                       Play and Stop and Reset, then 5 for each
                                       joystick; a button's own letter where it
                                       is held and a dot where it is not
  make-movie.py <frames> --as-presses  the same buttons as this repository's
                                       runners take them: --press F:N:MASK ...

The engine counts frames from 0 and the runners from 1, so row r of the movie
is the runners' frame r + 1.

The buttons are held in stretches, after the test tape's program has had time
to load: keys, then the first joystick's fire button and a direction.
"""
import sys

# the letters, in the order the package declares the buttons
LETTERS = "1234567890QWERTYUIOPASDFGHJKL<^ZXCVBNM$_>#%" + "udlrf" + "udlrf"
GROUPS = (43, 5, 5)
Q, ZERO, A, M = 10, 9, 20, 37
JOY1_UP, JOY1_FIRE = 43, 47

# (first row, rows, button)
STRETCHES = [(250, 30, Q), (300, 12, ZERO), (330, 25, JOY1_FIRE), (340, 40, A), (380, 20, JOY1_UP),
             (420, 15, M), (425, 30, JOY1_FIRE), (460, 10, Q)]


def main():
    frames = int(sys.argv[1])
    stretches = [s for s in STRETCHES if s[0] < frames]
    if "--as-presses" in sys.argv:
        print(" ".join("--press %d:%d:%x" % (first + 1, min(count, frames - first), 1 << button)
                       for first, count, button in stretches))
        return
    for row in range(frames):
        held = {button for first, count, button in stretches if first <= row < first + count}
        cells = "".join(LETTERS[i] if i in held else "." for i in range(len(LETTERS)))
        out, at = "|", 0
        for width in GROUPS:
            out += cells[at:at + width] + "|"
            at += width
        print(out)


if __name__ == "__main__":
    main()
