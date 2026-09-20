#!/usr/bin/env python3
"""device-crash.py: the last EidolonDemo crash report of a phone, short: exception type, the crashed frames of the app, symbolicated
against eidolon/out/EidolonDemo.app. Fetch first: charon --root $DEVICE_ROOT device fetch <report> /tmp/crash.plist"""
import bisect, plistlib, re, subprocess, sys
report = plistlib.load(open(sys.argv[1] if len(sys.argv) > 1 else '/tmp/crash.plist', 'rb'))['description']
print(re.search(r'Exception Type:.*', report).group(0))
base = int(re.search(r'\s(0x[0-9a-f]+) - .*\+EidolonDemo', report).group(1), 16)
nm = subprocess.run(['nm', '-n', 'eidolon/out/EidolonDemo.app/EidolonDemo'], capture_output=True, text=True).stdout
symbols = []
for line in nm.splitlines():
    part = line.split()
    if len(part) >= 3:
        try: symbols.append((int(part[0], 16), part[2]))
        except ValueError: pass
addresses = [a for a, _ in symbols]
backtrace = re.search(r'Last Exception Backtrace:\n\((.*?)\)', report, re.S)
frames = [int(x, 16) for x in backtrace.group(1).split()] if backtrace else []
print('exception backtrace, app frames:')
for frame in frames[:40]:
    if base <= frame < base + 0x300000:
        name = symbols[bisect.bisect_right(addresses, frame - base + 0x4000) - 1][1]
        print('  ', subprocess.run(['xcrun', 'swift-demangle', '--simplified', name], capture_output=True, text=True).stdout.strip()[:140])
print('crashed thread top:')
for m in re.finditer(r'^(\d+)\s+(\S+)\s+0x[0-9a-f]+ 0x[0-9a-f]+ \+ \d+', report.split('Thread 0 Crashed:')[1].split('Thread 1')[0], re.M):
    if m.group(1) in '0123456': print('  ', m.group(1), m.group(2))
