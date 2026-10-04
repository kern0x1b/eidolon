#!/usr/bin/env python3
"""detached.py: run a command in its own session so a tool call ending does not take it down.

    detached.py <log> <command> [args...]

Prints the child's pid. The child's output goes to <log>.
"""
import os
import subprocess
import sys

log = open(sys.argv[1], 'ab', buffering=0)
p = subprocess.Popen(sys.argv[2:], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
print(p.pid)
