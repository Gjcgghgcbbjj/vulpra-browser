#!/usr/bin/env python3
"""Route A' real-device smoke harness: discover Gecko child process PIDs from
Vulpra syslog output and emit StikDebug/debugserver attach commands.

Source of truth for the log line (VulpraEngineRuntime.swift:376-377):
  childLogger.notice("launch=<launchID> child=<childID> type=<processType,
  privacy:.public> pid=<pid> stage=<stage.rawValue>
  monotonic_ns=<...> failure=<...> reason=<..., privacy:.public>")

Usage:
  # Live stream (idevicesyslog) -> all content PIDs as they appear:
  idevicesyslog | python3 find_content_pids.py --type WebContent
  # StikDebug console export, file input:
  python3 find_content_pids.py --type WebContent --file console-export.log
  # Emit attach commands instead of plain PIDs:
  ... | python3 find_content_pids.py --attach-commands

NOT verified on a device yet (2026-08-11 draft): regex is derived from the
Swift source, but actual os_log rendering may add quotes/prefixes; keep one
pattern per renderer in PATTERNS if needed.

Exit code 0 if at least one PID of the requested type was seen.
"""
import argparse
import re
import sys

# The os_log subsystem/format may prefix lines with bundle id + timestamp;
# anchor on the fields we own. pid is emitted public (no redaction).
LINE_RE = re.compile(
    r"launch=(\d+)\s+child=(\d+)\s+type=([A-Za-z]+)\s+pid=(\d+)\s+stage=(\d+)"
)

# Gecko child process types (mozilla::ProcessType on iOS).
KNOWN_TYPES = {"WebContent", "GPU", "RDD", "Networking", "Utility", "GeckoMain"}


def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--type", default="WebContent",
                   help="Process type to report (default WebContent)")
    p.add_argument("--file", help="Read from file instead of stdin")
    p.add_argument("--attach-commands", action="store_true",
                   help="Emit StikDebug-style vAttach;hexpid lines")
    p.add_argument("--stikdebug-url", action="store_true",
                   help="Emit stikdebug://enable-jit URL per PID (StikDebug "
                        "HomeView.handleExternalURL host=enable-jit)")
    p.add_argument("--bundle-id", default="com.vulpra.browser.engine-process",
                   help="Engine Process appex bundle id for the URL (default "
                        "com.vulpra.browser.engine-process)")
    p.add_argument("--stage-max", type=int, default=3,
                   help="Ignore lines with stage > N (debug trace noise)")
    return p.parse_args()


def main():
    args = parse_args()
    src = open(args.file, encoding="utf-8", errors="replace") if args.file else sys.stdin
    seen = {}          # (launch, child, type) -> pid
    order = []
    for line in src:
        m = LINE_RE.search(line)
        if not m:
            continue
        launch, child, ptype, pid, stage = m.groups()
        stage = int(stage)
        if stage > args.stage_max:
            continue
        key = (launch, child, ptype)
        if key not in seen:
            seen[key] = int(pid)
            order.append(key)
        elif seen[key] != int(pid):
            # PID changed for same (launch, child, type): keep latest.
            seen[key] = int(pid)
    if args.file:
        src.close()

    wanted = [(k, seen[k]) for k in order if k[2] == args.type]
    if not wanted:
        print(f"# no {args.type} PID seen (any types: "
              f"{sorted({k[2] for k in seen})})", file=sys.stderr)
        return 1

    for (launch, child, ptype), pid in wanted:
        if args.attach_commands:
            # StikDebug JITEnableContext vAttach takes a hex PID.
            print(f"vAttach;{pid:x}  # launch={launch} child={child} type={ptype}")
        elif args.stikdebug_url:
            print(f"stikdebug://enable-jit?pid={pid}&bundle-id={args.bundle_id}"
                  f"  # launch={launch} child={child} type={ptype}")
        else:
            print(pid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
