---
title: "Fix the root readme: three missing breaking changes and a JSON Lines example that fails under AOT"
kind: problem
status: pending
created: 2026-11-25
summary: "The package readme's upgrade list omits three changes that break 1.x code, and its JSON Lines example fails where reflection-based serialization is off."
---

## Why
Found while writing the .NET guide of the website (`docs/dotnet/`), by compiling and running against the current API and against `git show v1.0.2`. The .NET content of the root `readme.md` has since moved to the package readme, `dotnet/JQLite/readme.md`.

1. **"Upgrading from 1.x" omits three breaking changes:**
   - `Jq.Parse(text, null)` no longer compiles: `Parse(string, JqOptions)` and `Parse(string, JqResolver)` make the call ambiguous (CS0121).
   - `Jq.EvaluateAsync(expression, input, token)` no longer compiles: the third parameter is now the variables, so the token must be passed by name.
   - In 1.x `halt` and `halt_error` ended an evaluation silently with no results; now `halt_error` throws `JqHaltException` and `halt` keeps the results produced before it.
2. **The JSON Lines example** ("Streaming JSONL" in `dotnet/JQLite/readme.md`) reads the file with `JsonSerializer.DeserializeAsyncEnumerable<JsonElement>(stream, topLevelValues: true)`. That fails when reflection-based serialization is disabled, the default in file-based apps and in Native AOT, and `dotnet/JQLite/JQLite.csproj` sets `IsAotCompatible`.

## What to do
- [ ] Add the three items to "Upgrading from 1.x", in the wording of `docs/dotnet/upgrading.md`.
- [ ] In "Streaming JSONL", pass a source-generated `JsonTypeInfo` or show the line reader of `docs/dotnet/jsonl.md`, and say what the example needs.

## Where
`dotnet/JQLite/readme.md`; the corrected text is in `docs/dotnet/upgrading.md` and `docs/dotnet/jsonl.md`
