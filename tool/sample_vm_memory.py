#!/usr/bin/env python3
"""Read-only Dart heap samples alongside the native profile test.

python3 tool/sample_vm_memory.py /tmp/skyway-native-soak.log output.json
The local VM service URL is discovered from Flutter's log, not persisted.
No forced GC: these are ordinary live heap measurements, not retained-heap proof.
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

log, output = map(Path, sys.argv[1:3])
url = re.search(r"at (http://127\.0\.0\.1:[^\s]+)", log.read_text())[1]


def rpc(method, **parameters):
    query = urllib.parse.urlencode(parameters)
    with urllib.request.urlopen(url + method + "?" + query, timeout=10) as response:
        return json.load(response)["result"]


isolate = rpc("getVM")["isolates"][0]["id"]
samples = []
started = time.monotonic()
while True:
    try:
        usage = rpc("getMemoryUsage", isolateId=isolate)
        samples.append({"seconds": round(time.monotonic() - started, 3), **usage})
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(samples, indent=2) + "\n")
        print(json.dumps(samples[-1]), flush=True)
    except (OSError, KeyError):
        break  # The test has shut down its VM service.
    time.sleep(60)
