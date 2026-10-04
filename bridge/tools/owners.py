#!/usr/bin/env python3
"""owners.py: the declaration a line of a `.swiftinterface` stands in.

A `.swiftinterface` is machine-formatted: a nested declaration is indented two spaces per level, and the
braces are not a reliable guide because an interface is one flat list of top-level declarations with
members indented under them. So the owner is a stack by **indentation**: a declaration at indent *i* pops
every entry whose indent is *i* or deeper and pushes itself; an attribute line and a `where` continuation
change nothing; and a member's owner is the joined names on the stack at that line.

An `extension X` pushes `X` with the module prefix dropped — `extension SwiftUICore.Image` is `Image`, and
`extension SwiftUI.Anchor.Source` is `Anchor.Source` — so a member of `Anchor.Source` is never filed under
`Anchor` and a member of a nested `ResizingMode` is `Image.ResizingMode`.
"""
import re

MODULES = {'Swift', 'SwiftUI', 'SwiftUICore', 'Foundation', 'CoreGraphics', 'UIKit', 'Combine',
           'Observation', 'CoreTransferable', 'DeveloperToolsSupport', 'Darwin', 'ObjectiveC'}

DECL = re.compile(r'^(?:@\w+(?:\([^)]*\))?\s+)*'
                  r'(?:public|open|package|@usableFromInline|@inlinable|@_alwaysEmitIntoClient|@MainActor|@preconcurrency|'
                  r'nonisolated|final|indirect|@frozen|static)*\s*'
                  r'(struct|class|enum|protocol|actor|typealias|extension)\s+([\w.]+)')


def unmodule(name):
    parts = name.split('.')
    return '.'.join(parts[1:]) if parts and parts[0] in MODULES else name


def indent_of(line):
    return len(line) - len(line.lstrip(' ')) if line.strip() else None


def is_declaration(line):
    stripped = line.strip()
    if not stripped or stripped.startswith('//') or stripped.startswith('@'):
        return None
    m = DECL.match(stripped)
    if not m:
        return None
    return m.group(1), unmodule(m.group(2))


def walk(lines):
    """yields (line number, text, owner-as-written or None) for every line of an interface"""
    stack = []                       # (indent, name)
    for number, line in enumerate(lines, start=1):
        indent = indent_of(line)
        declaration = is_declaration(line)
        owner = '.'.join(name for _, name in stack) if stack else None
        if declaration and indent is not None:
            while stack and stack[-1][0] >= indent:
                stack.pop()
            owner = '.'.join(name for _, name in stack) if stack else None
            kind, name = declaration
            stack.append((indent, name))
            yield number, line, owner
            continue
        if indent is not None:
            while stack and stack[-1][0] >= indent:
                stack.pop()
        yield number, line, owner
