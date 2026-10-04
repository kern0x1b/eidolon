#!/usr/bin/env python3
"""surf.py: the 26.2 SwiftUI + SwiftUICore surface for the types this band owns, one line per declaration.

Reads the SDK's own `.swiftinterface` files — SwiftUI and SwiftUICore, the two halves Apple split the
surface between — from `$APPLE_26_SDK`, which defaults to the charon SDK 26.2 checkout under `$HOME`.
Braces are counted by `braces.py`, the same counter `ours.py` uses over our own sources, so a depth means
the same thing on both sides.

Usage: surf.py TYPES-FILE > surface-26.2.tsv
Then: gaps.py <ours.tsv> <surface-26.2.tsv> says what of it this tree does not declare.
"""
import re, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from braces import braces

SDK = os.environ.get('APPLE_26_SDK') or os.path.expanduser(
    '~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk')
SWIFTUI = os.path.join(SDK, 'System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface')
COREC = os.path.join(SDK, 'System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface')

want = set()
for line in open(sys.argv[1]):
    line = line.strip()
    if line and not line.startswith('#'):
        want.add(line)


def strip_ns(text):
    text = re.sub(r'SwiftUI\.', '', text)
    text = re.sub(r'SwiftUICore\.', '', text)
    text = re.sub(r'Swift\.', '', text)
    text = re.sub(r'Foundation\.', '', text)
    text = re.sub(r'QuartzCore\.', '', text)
    text = re.sub(r'CoreGraphics\.', '', text)
    return text


def scan(path, out):
    lines = open(path).read().split('\n')
    depth = 0
    owner = None
    in_block = in_multiline = hashes = 0
    pending = []          # @attribute lines above the declaration
    for line in lines:
        s = line.strip()
        if not s or s.startswith('#'):
            pending = []
            continue
        if depth == 0:
            m = re.match(r'(?:public |open |package )?(?:final )?(?:@frozen )?(?:indirect )?(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)', s)
            if m is None:
                m = re.match(r'extension ((?:SwiftUI|SwiftUICore)\.)?([\w.]+)', s)
                if m:
                    pending = []
                    attrs = pending
                    # the whole extended name, and a member of `Anchor.Source` belongs to `Anchor.Source`
                    extended = m.group(2)
                    if extended in want and '{' in s:
                        owner = extended
                    elif any(extended == f'{name}.{suffix}' or extended.endswith(f'.{suffix}')
                             for name in want for suffix in ('Source',)) and '{' in s:
                        owner = extended
                    else:
                        owner = None
                else:
                    pending = [s] if s.startswith('@') else []
                opened, closed, in_block, in_multiline, hashes = braces(s, in_block, in_multiline, hashes)
                depth += opened - closed
                continue
            owner = m.group(1) if m.group(1) in want else None
            if owner:
                out.append((owner, 'type', strip_ns(s)))
            pending = [s] if s.startswith('@') else []
            opened, closed, in_block, in_multiline, hashes = braces(s, in_block, in_multiline, hashes)
            depth += opened - closed
            continue
        # inside a section
        dead = any(re.search(r'@available\(iOS,\s*unavailable', a) for a in pending)
        if owner and not dead and s not in ('get', 'set', '}', '{') and not s.startswith('//'):
            body = s
            if '{' in body:
                body = body[:body.index('{')]
            body = body.strip()
            if not body or body in ('{',):
                pass
            elif re.match(r'^(public |open |package )?(static )?(final )?(mutating )?(indirect )?(struct|class|enum|protocol|actor|typealias)\s', body) and not re.search(r'\bfunc\b', body):
                out.append((owner, 'type', strip_ns(body)))
            elif re.search(r'\bfunc (\w+)', body):
                fn = re.search(r'\bfunc (\w+)', body)
                args = re.search(r'\((.*?)\)(\s*(async\s*)?(throws\s*)?->|$)', body)
                out.append((owner, 'func', fn.group(1) + '(' + (args.group(1) if args else '') + ')'))
            elif re.search(r'\binit\b', body):
                out.append((owner, 'init', strip_ns(body)))
            elif re.search(r'\bvar (\w+)', body):
                vn = re.search(r'\bvar (\w+)', body)
                out.append((owner, 'var', vn.group(1)))
            elif re.search(r'\b(let|case) (\w+)', body):
                vn = re.search(r'\b(?:let|case) (\w+)', body)
                out.append((owner, 'const', vn.group(1)))
            elif re.search(r'\bsubscript\b', body):
                out.append((owner, 'subscript', 'subscript'))
        if s.startswith('@'):
            pending = [s]
        else:
            pending = []
        opened, closed, in_block, in_multiline, hashes = braces(s, in_block, in_multiline, hashes)
        depth += opened - closed
        if depth == 0:
            owner = None
            pending = []


out = []
scan(SWIFTUI, out)
scan(COREC, out)
seen = set()
for owner, kind, text in out:
    key = (owner, kind, text)
    if key in seen:
        continue
    seen.add(key)
    print(f'{owner}\t{kind}\t{text}')
