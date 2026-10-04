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
from owners import walk

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
    pending = []          # the @attribute lines above the declaration
    for number, line, owner in walk(lines):
        s = line.strip()
        if not s or s.startswith('#'):
            pending = []
            continue
        if owner is None:
            if s.startswith('@'):
                pending = s
            continue
        # a type of ours, or a type nested in one: matched on the last component, and the owner keeps
        # the whole path, so a member of `Image.ResizingMode` is never filed under `Image`
        # a type of ours, or anything nested in one: `Image` in `want` admits `Image.ResizingMode`
        # and `Anchor.Source`, and never a type that is neither
        if not (owner.split('.', 1)[0] in want):
            continue
        if re.search(r'@available\(iOS,\s*unavailable', pending or ''):
            pending = []
            continue
        body = s[:s.index('{')] if '{' in s else s
        if not body:
            continue
        for pattern, kind, group in ((r'\bsubscript\b', 'subscript', 0),
                                     (r'\binit\b', 'init', 0),
                                     (r'\bfunc (\w+)', 'func', 1),
                                     (r'\bvar (\w+)', 'var', 1),
                                     (r'\bcase (\w+)', 'const', 1),
                                     (r'\b(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)', 'type', 1)):
            m = re.search(pattern, body)
            if m:
                out.append((owner, kind, m.group(group) if group else 'subscript' if kind == 'subscript' else 'init'))
                break
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
