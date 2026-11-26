---
title: "Make bench/run.ps1 and the bench.json files run on Linux and macOS"
kind: gap
status: pending
created: 2026-11-26
summary: "Three bench.json files use Windows-only commands, so `pwsh bench/run.ps1` fails on Linux and macOS; the WSL run for the readme had to patch them in a clone."
---

## Why

`bench/README.md` presents `pwsh bench/run.ps1` as the way to run the benchmark, and the readme's Performance section now quotes a run on Ubuntu (WSL 2), but the configuration only works on Windows:

- `go/bench.json` builds and runs `bin/jqlite-bench.exe`;
- `java/bench.json` builds with `cmd /c .\mvnw.cmd`;
- `python/bench.json` runs `python` (Ubuntu has only `python3`).

The run of 2026-11-26 patched them in a clone to `go build -o bin/jqlite-bench`, `sh ./mvnw -q -DskipTests package` and `python3 crossbench.py`.

## What to do

Let a `bench.json` give commands per OS (for example optional `build_unix`/`run_unix`, or a `{exe}` placeholder that `run.ps1` expands), or have `run.ps1` pick the Maven wrapper, the executable suffix and the Python command from `$IsWindows`. Then document in `bench/README.md` that the benchmark runs on Linux and macOS.

## Where

`bench/run.ps1`, `bench/README.md`, `go/bench.json`, `java/bench.json`, `python/bench.json`.
