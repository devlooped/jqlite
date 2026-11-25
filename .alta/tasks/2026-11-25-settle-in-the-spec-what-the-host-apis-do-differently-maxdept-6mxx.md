---
title: "Settle in the spec what the host APIs do differently: MaxDepth range, no-clock state, circular import position, JSON Lines helpers"
kind: problem
status: pending
created: 2026-11-25
summary: "The six host APIs disagree on the valid depth limit, on whether a host can have no clock and on their JSON Lines helpers, and the spec does not decide."
---

## Why
Found while writing the same pages for six implementations (`docs/*/options.md`, `modules.md`, `jsonl.md`), each checked by running code.

1. **`MaxDepth` has no range in spec §11/§12, and each implementation chose one:**

   | Implementation | Where | 0 or less | Upper bound |
   | --- | --- | --- | --- |
   | .NET | `dotnet/JQLite/JqOptions.cs:25` | accepted: every call of a jq-defined function fails, `map` included | none |
   | TypeScript | `typescript/src/jqExpression.ts:36` | the same; `NaN` and `Infinity` mean no limit | none |
   | Go | `go/jqlite.go:59` | 0 and negative values mean 1000 (`go/README.md:49` says only "0 is 1000") | none |
   | Python | `python/jqlite/options.py:73` | 0 accepted, negative is `ValueError` | 100,000 |
   | Java | `java/.../JqOptions.java:86` | `IllegalArgumentException` below 1 | `MAX_DEPTH_LIMIT` |
   | Rust | `rust/src/jq_options.rs:29` | `usize`: 0 accepted | none |

2. **The host without a clock** (spec §12, `spec/jqlite.md:1305`: `now` is the error `now/0 requires a host clock`, the local zone is UTC) exists only in Python. Go (`go/jqlite.go:177-193`), Java (`JqOptions.withClock(null)` throws, `JqOptions.java:65`), Rust, TypeScript and .NET always have a clock. The spec does not say whether that conforms.
3. **Spec §9.11 does not locate the error of a circular import.** The implementations report it at the directive of the module that closes the cycle (`circular import of A at B, line 1, column 1`).
4. **JSON Lines helpers differ**, and §12 only says each value is evaluated alone: Rust has none; .NET (`Jq.EvaluateAsync`) and TypeScript (`Jq.evaluateAsync`) only asynchronous; Java (`Jq.evaluateLines`) only synchronous; Python has both but they take no options; Go has `Lines` and `EvaluateLines`.

## What to do
- [ ] State the range of `MaxDepth` in §11/§12, make each host API follow it with a test, fix `go/README.md`.
- [ ] Say in §12 that offering the no-clock state is the host's choice, or require it.
- [ ] Give the position of the circular import error in §9.11, with a corpus case if the text is fixed.
- [ ] Decide which JSON Lines helpers a host API has and add the missing ones.
- [ ] Update `docs/*/options.md`, `modules.md`, `jsonl.md` and `api.md`, which describe today's behaviour.

## Where
`spec/jqlite.md` §9.11, §11, §12; the options and entry points of each implementation; `docs/`
