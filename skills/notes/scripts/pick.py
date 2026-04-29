#!/usr/bin/env python3
"""Interactive picker using raw-mode TTY. stdlib only.

Usage:
  pick.py one  "Prompt"  opt1 opt2 ...        # echoes chosen option
  pick.py many "Prompt"  opt1 opt2 ...        # echoes chosen options, one per line
                                              #   all checked by default

Reads input from /dev/tty so it works inside $(...) capture.
Writes UI to /dev/tty (stderr-equivalent); only the result goes to stdout.
"""
from __future__ import annotations
import os, sys, termios, tty

ESC = "\x1b"
CSI = ESC + "["


def main() -> int:
    if len(sys.argv) < 4:
        print("usage: pick.py {one|many} <prompt> opt1 opt2 ...", file=sys.stderr)
        return 2
    mode, prompt, *opts = sys.argv[1], sys.argv[2], *sys.argv[3:]
    if not opts:
        print("pick.py: no options", file=sys.stderr)
        return 2

    try:
        tty_in = open("/dev/tty", "rb", buffering=0)
        tty_out = open("/dev/tty", "w", buffering=1)
    except OSError:
        # not a tty — print first option (single) or all (multi)
        if mode == "one":
            print(opts[0])
        else:
            print("\n".join(opts))
        return 0

    multi = mode == "many"
    sel = 0
    checked = [True] * len(opts) if multi else None

    def write(s: str) -> None:
        tty_out.write(s)
        tty_out.flush()

    def read_key() -> str:
        b = tty_in.read(1)
        if b == b"\x1b":
            b += tty_in.read(2)  # blocking — we're in raw, kernel hands them over
        return b.decode("utf-8", errors="replace")

    def render(first: bool) -> None:
        if not first:
            write(f"{CSI}{len(opts)}A")  # cursor up N
        for i, o in enumerate(opts):
            line = ""
            if multi:
                mark = "[x]" if checked[i] else "[ ]"
                row = f" {mark} {o}"
            else:
                row = f" {o}"
            if i == sel:
                line = f"{CSI}2K\r{CSI}7m>{row}{CSI}0m\n"
            else:
                line = f"{CSI}2K\r {row}\n"
            write(line)

    fd = tty_in.fileno()
    old = termios.tcgetattr(fd)
    write(f"{prompt}\n")
    write(f"{CSI}?25l")  # hide cursor
    try:
        tty.setcbreak(fd)
        render(first=True)
        while True:
            k = read_key()
            if k in ("\x1b[A", "k"):
                sel = (sel - 1) % len(opts)
            elif k in ("\x1b[B", "j"):
                sel = (sel + 1) % len(opts)
            elif multi and k == " ":
                checked[sel] = not checked[sel]
            elif k in ("\r", "\n"):
                break
            elif k in ("q", "\x03"):  # q or Ctrl-C
                write(f"{CSI}?25h")
                return 130
            else:
                continue
            render(first=False)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        write(f"{CSI}?25h\n")  # show cursor

    if multi:
        for o, c in zip(opts, checked):
            if c:
                print(o)
    else:
        print(opts[sel])
    return 0


if __name__ == "__main__":
    sys.exit(main())
