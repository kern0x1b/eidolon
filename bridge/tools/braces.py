#!/usr/bin/env python3
"""braces.py: the braces a line of Swift really opens and closes.

Counting them with `count('{')` is wrong the moment a line carries a brace in a string or a comment, and
from that line on any walk over the file sits at the wrong depth and attributes nothing after it. So the
line is read as Swift: `//`, `/* */`, a plain string, a multi-line one and a raw one with any number of
hashes carry no brace, and a block comment or a multi-line literal carries its state to the next line.

One function, used by both halves of the comparison — `surf.py` over Apple's interfaces and `ours.py`
over ours — so a depth is counted the same way on each side.

Returns (opened, closed, in_block, in_multiline, hashes).
"""


def braces(line, in_block=False, in_multiline=False, hashes=0):
    opened = closed = 0
    i, n = 0, len(line)
    while i < n:
        if in_block:
            if line.startswith('*/', i):
                in_block = False
                i += 2
            else:
                i += 1
            continue
        if in_multiline:
            closing = ('#' * hashes + '"""') if hashes else '"""'
            if line.startswith(closing, i):
                in_multiline = False
                i += len(closing)
                continue
            i += 1
            continue
        if line.startswith('//', i):
            break
        if line.startswith('/*', i):
            in_block = True
            i += 2
            continue
        if line[i] == '#':
            run = 0
            while i + run < n and line[i + run] == '#':
                run += 1
            if i + run < n and line[i + run] == '"':
                hashes = run
                i += run + 1
                if line.startswith('"""', i):
                    in_multiline = True
                    i += 3
                    continue
                closing = '#' * hashes + '"'
                end = line.find(closing, i)
                i = n if end < 0 else end + len(closing)
                continue
            i += run
            continue
        if line[i] == '"':
            if line.startswith('"""', i):
                in_multiline = True
                i += 3
                continue
            i += 1
            while i < n:
                if line[i] == '\\':
                    i += 2
                    continue
                if line[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if line[i] == '{':
            opened += 1
        elif line[i] == '}':
            closed += 1
        i += 1
    return opened, closed, in_block, in_multiline, hashes


if __name__ == '__main__':
    import sys
    depth = in_block = in_multiline = hashes = 0
    for line in sys.stdin:
        opened, closed, in_block, in_multiline, hashes = braces(line.rstrip('\n'), in_block, in_multiline, hashes)
        depth += opened - closed
    print(depth)
