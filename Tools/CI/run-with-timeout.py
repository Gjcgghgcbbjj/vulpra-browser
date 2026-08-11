#!/usr/bin/env python3
"""Run a command under a monotonic-clock timeout.

The previous implementation used perl's alarm(), which counts down on
CLOCK_REALTIME. Virtualized CI hosts can step the wall clock by minutes
(NTP/adjtime discipline, VM suspend/resume catch-up), which makes a
wall-clock alarm fire spuriously and kill commands that are nowhere near
their deadline. time.monotonic() is immune to wall-clock steps.

Exit-code semantics match the previous implementation so callers that
inspect specific statuses keep working:
  * normal/signalled child exit status is propagated (128+signal for signal
    deaths),
  * on timeout the child is sent SIGALRM (like alarm()) and this process
    exits 142 (128+SIGALRM). run-simulator-navigation.sh relies on 142 to
    record log_show_timed_out=true.
"""
from __future__ import annotations

import os
import signal
import sys
import time

KILL_GRACE_SECONDS = 2.0


def wait_for_child(pid: int, deadline: float) -> int:
    """Wait until the child exits or the monotonic deadline passes."""
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            try:
                os.kill(pid, signal.SIGALRM)
            except ProcessLookupError:
                pass
            kill_deadline = time.monotonic() + KILL_GRACE_SECONDS
            while True:
                try:
                    done, _status = os.waitpid(pid, os.WNOHANG)
                except ChildProcessError:
                    return 142
                if done:
                    return 142
                if time.monotonic() >= kill_deadline:
                    try:
                        os.kill(pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                time.sleep(0.05)
        try:
            done, status = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            return 142
        if done:
            exit_code = os.waitstatus_to_exitcode(status)
            # os.waitstatus_to_exitcode reports signal deaths as negative
            # (-signum); the shell convention used by callers ($?) is
            # 128+signum. Normalise so a signal-killed child surfaces as
            # e.g. 137 for SIGKILL instead of 247 (256-9).
            if exit_code < 0:
                exit_code = 128 - exit_code
            return exit_code
        time.sleep(min(0.05, remaining))


def main() -> int:
    if len(sys.argv) < 3:
        print(f"usage: {sys.argv[0]} SECONDS COMMAND [ARGS...]", file=sys.stderr)
        return 64
    try:
        seconds = float(sys.argv[1])
    except ValueError:
        print(f"invalid timeout: {sys.argv[1]!r}", file=sys.stderr)
        return 64
    if seconds <= 0:
        print(f"invalid timeout: {sys.argv[1]!r}", file=sys.stderr)
        return 64
    command = sys.argv[2:]

    deadline = time.monotonic() + seconds
    pid = os.fork()
    if pid == 0:
        try:
            os.execvp(command[0], command)
        except OSError as error:
            print(f"{command[0]}: {error}", file=sys.stderr)
            os._exit(127)

    try:
        return wait_for_child(pid, deadline)
    except KeyboardInterrupt:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        return 130


if __name__ == "__main__":
    sys.exit(main())
