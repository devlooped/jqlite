---
title: "Fix the host API defects found in the ports: Python clock=None, Java resource resolver, Go value conversions, Rust exports and traits, TypeScript JsonInput"
kind: problem
status: pending
created: 2026-11-25
summary: "Five small defects of the ports' public APIs, one or two per port, each found and checked while writing that port's guide."
---

## Why
Each was found by running code against the port while writing its section of the website; the guide of each port documents today's behaviour with a note.

- **Python**: `python/jqlite/options.py:68` types `clock: Clock`, but `None` is accepted and is the host without a clock of spec §12 (`python/jqlite/builtins/date_natives.py:23-24`, 47, 94). A type checker rejects `Options(clock=None)` although it works; the README does not mention it.
- **Java**: the doc comment of `JqResourceResolver` (`JqResourceResolver.java:11-12`) says `.jq` or `.json` is added "unless the path ends with one"; the code (lines 46-49) only checks the suffix of the directive's own kind, so `include "x.json"` looks for `x.json.jq`.
- **Go**: `*Array` and `*Object` have methods that build new ones (`Append`, `Concat`, `SetItem`, `Merge`…, `go/internal/values/jq_array.go:80-132`), but no exported function makes a `Value` of the result (`values.FromArray` is internal), so it cannot go into an evaluation. Also, `Expression.Lines` (`go/lines.go:36`) validates the variable names only when it evaluates the first value: an empty stream never reports an invalid name.
- **Rust**:
  - `JqHandler`, the type of the `debug` and `stderr` options, is `pub` in `rust/src/jq_options.rs:11` but not re-exported by `rust/src/lib.rs`: users cannot name it.
  - `rust/README.md:86` says `From` exists "for the usual Rust types"; `rust/src/json.rs:32-74` has no `i64`, `u32`, `u64`, `usize` or `f32`.
  - `JqValue`, `JqArray`, `JqObject` and `JqExpression` implement no `PartialEq` (a host test cannot `assert_eq!` two values), and the last three no `Debug`.
  - `JqObject::from_owned` (`rust/src/values/jq_object.rs:93`) is public and says "keys must be distinct" without checking.
- **TypeScript**: `JsonInput` (`typescript/src/json/jsonValueAdapter.ts:25`) does not allow an `undefined` array element, which the converter accepts and makes `null` (its comment at line 69, and the README): valid JavaScript is a type error in TypeScript.

## What to do
- [ ] Python: type the field `Clock | None`, document `None`, test `now` and `localtime` with it.
- [ ] Java: make the comment and the code agree, by what the .NET resolvers do for the same path, with a test.
- [ ] Go: export the two conversions to `Value`; validate the variables of `Lines` before the first read.
- [ ] Rust: re-export `JqHandler`; add the `From` conversions or make the README exact; implement `PartialEq` (§4.2) and `Debug`; make `from_owned` crate-private or checked.
- [ ] TypeScript: make the array element type `JsonInput | undefined`.
- [ ] Remove the matching notes from `docs/python/options.md`, `docs/java/modules.md`, `docs/go/api.md`, `docs/rust/api.md`, `docs/typescript/values.md`.

## Where
`python/jqlite/options.py`, `java/.../JqResourceResolver.java`, `go/value.go`, `go/lines.go`, `rust/src/lib.rs`, `rust/src/json.rs`, `rust/src/values/`, `typescript/src/json/jsonValueAdapter.ts`, and the guides in `docs/`
