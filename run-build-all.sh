#!/bin/bash
# run-build-all.sh — detached orchestrator wrapper with logging
# (avoids Start-Process argument-quoting pitfalls with shell redirects)
LOG=/g/mpv-build/build-all-run.log
exec >"$LOG" 2>&1
echo "### run-build-all.sh started: $(date) ###"
/g/mpv-build/build-all.sh
rc=$?
echo "ORCHESTRATOR_EXIT=$rc"
echo "### finished: $(date) ###"
exit $rc
