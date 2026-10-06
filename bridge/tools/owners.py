#!/usr/bin/env python3
"""owners.py: the declaration a line of a `.swiftinterface` stands in.

A `.swiftinterface` is machine-formatted: a nested declaration is indented two spaces per level, and the
braces are not a reliable guide because an interface is one flat list of top-level declarations with
members indented under them. So the owner is a stack by **indentation**: a declaration at indent *i* pops
every entry whose indent is *i* or deeper and pushes itself; an attribute line and a `where` continuation
change nothing; and a member's owner is the joined names on the stack at that line.

An `extension X` pushes `X` with the module prefix dropped - `extension SwiftUICore.Image` is `Image`, and
`extension SwiftUI.Anchor.Source` is `Anchor.Source` - so a member of `Anchor.Source` is never filed under
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
    # not `startswith('@')`: a declaration may carry its own attributes, and the pattern
    # already allows them - `@frozen public enum Orientation` is a declaration, not an attribute
    if not stripped or stripped.startswith('//'):
        return None
    m = DECL.match(stripped)
    if not m:
        return None
    return m.group(1), unmodule(m.group(2))


def walk(lines, trace=False):
    """yields (line number, text, owner-as-written or None) for every line of an interface

    A preprocessor line and an attribute line are neither a declaration nor a member: they must not push
    and must not pop, and `#if compiler(...)` in particular sits at the indent of the block it guards, so
    treating it as one closes the block above it.
    """
    stack = []                       # (indent, name)
    for number, line in enumerate(lines, start=1):
        indent = indent_of(line)
        stripped = line.strip() if line.strip() else ''
        preprocessor = stripped.startswith('#')
        attribute = stripped.startswith('@')
        # a line may begin with an attribute and still be the declaration itself:
        # `@frozen public enum Orientation` is one, and reading it as an attribute left the
        # stack on `Image` and lost the nested type with every member under it
        declaration = None if preprocessor else is_declaration(line)
        attribute = attribute and declaration is None
        before = ' > '.join(name for _, name in stack)
        if declaration and indent is not None:
            while stack and stack[-1][0] >= indent:
                stack.pop()
            kind, name = declaration
            stack.append((indent, name))
            owner = '.'.join(n for _, n in stack)
            decision = f'push {kind} {name}'
        else:
            if indent is not None and not preprocessor and not attribute:
                while stack and stack[-1][0] >= indent:
                    stack.pop()
            owner = '.'.join(name for _, name in stack) if stack else None
            decision = 'skip (preprocessor)' if preprocessor else ('skip (attribute)' if attribute else 'member')
        if trace:
            print(f'{number:4} | {indent if indent is not None else -1:2} | {before or "-":40} -> '
                  f'{" > ".join(n for _, n in stack) or "-":40} | {decision:28} | {stripped[:44]}')
        yield number, line, owner
