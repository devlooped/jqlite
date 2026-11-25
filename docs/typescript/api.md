---
title: "API reference"
---

# API reference

The package `jqlite` has two entry points. `jqlite` exports everything below except
`JqFileResolver`, which `jqlite/node` exports. Names marked *type* are TypeScript types only, with
no run-time value.

```typescript
import { Jq, JqExpression, JqError, JqHaltError, JqParseError } from "jqlite";
import type { JqClock, JqModuleKind, JqOptions, JqResolver, JqVariables, JsonInput, JsonValue } from "jqlite";
import { JqFileResolver } from "jqlite/node";
```

## Jq

A class of static methods; it cannot be instantiated.

| Member | Description |
| --- | --- |
| `static parse(expression: string, options?: JqOptions): JqExpression` | Parses and binds `expression`, loading its modules; throws `JqParseError`. An empty expression is `.`. See [Evaluating](evaluate.md). |
| `static evaluate(expression: string, input: JsonInput, variables?: JqVariables): JsonValue[]` | Parses with the default options and returns all the results on `input`. |
| `static evaluateAsync(expression: string \| JqExpression, inputs: AsyncIterable<JsonInput> \| Iterable<JsonInput>, variables?: JqVariables): AsyncGenerator<JsonValue, void, undefined>` | Evaluates each value of `inputs` alone and yields the results of each in turn. See [JSON Lines](jsonl.md). |

## JqExpression

A parsed expression, returned by `Jq.parse`; immutable. Its constructor is internal.

| Member | Description |
| --- | --- |
| `evaluate(input: JsonInput, variables?: JqVariables): JsonValue[]` | All the results, computed before the array is returned. |
| `evaluateEach(input: JsonInput, onResult: (result: JsonValue) => boolean, variables?: JqVariables): void` | Gives each result to `onResult` as it is produced; `onResult` returns `false` to stop. |
| `evaluateText(input: string, variables?: JqVariables): string[]` | Takes the input as JSON text and returns the canonical JSON text of each result, in jqlite's key order. |

All three throw `JqError` for an uncaught error and `JqHaltError` for `halt_error`; see
[Errors](errors.md).

## Options

| Symbol | Description |
| --- | --- |
| `JqOptions` (*type*) | The options of `Jq.parse`; every field optional and read-only. See [Options](options.md). |
| `JqOptions.resolver?: JqResolver` | Resolves `import`, `include` and `modulemeta`; without one, no module exists. |
| `JqOptions.environment?: Readonly<Record<string, string>> \| ReadonlyMap<string, string>` | The variables of `$ENV` and `env`; default `process.env` where there is one. |
| `JqOptions.clock?: JqClock` | The clock and local zone; default the system's, from `Date`. |
| `JqOptions.maxDepth?: number` | The most calls of jq-defined functions active at once; default `1000`. |
| `JqOptions.debug?: (value: JsonValue) => void` | Receives the values of `debug`; default: dropped. |
| `JqOptions.stderr?: (value: JsonValue) => void` | Receives the values of `stderr`; default: dropped. |
| `JqClock` (*type*) | The source of `now` and of the local zone. |
| `JqClock.now(): number` | The current time, in seconds since the Unix epoch. |
| `JqClock.offset(seconds: number): number` | The offset of the local zone at that instant, in seconds east of UTC. |
| `JqClock.abbreviation?(seconds: number): string \| null` | Optional: the zone's abbreviation at that instant; without one, `%Z` prints the offset. |
| `JqVariables` (*type*) | `Readonly<Record<string, JsonInput>> \| ReadonlyMap<string, JsonInput>`: host variables by name without `$`. See [Variables](variables.md). |

## Resolvers

| Symbol | Description |
| --- | --- |
| `JqModuleKind` (*type*) | `"code" \| "data"`: a `.jq` module or a data module of JSON values. |
| `JqResolver` (*type*) | Finds and reads modules. See [Modules](modules.md). |
| `JqResolver.getCanonicalPath(path: string, kind: JqModuleKind, metadata: JsonValue \| undefined, fromPath: string \| null): string \| null` | The identity of the module `path` imported from `fromPath` (`null`: the program); `null` when there is none. |
| `JqResolver.open(canonicalPath: string): string` | The text of a module. |
| `class JqFileResolver implements JqResolver` | From `jqlite/node`: modules in files, `.jq` or `.json` added to a path without an extension. |
| `new JqFileResolver(baseDirectory: string)` | `baseDirectory` is what the program's own paths are relative to. |
| `JqFileResolver.baseDirectory: string` | The base directory, made absolute. Read-only. |
| `JqFileResolver.getCanonicalPath(path: string, kind: JqModuleKind, metadata: JsonValue \| undefined, fromPath: string \| null): string \| null` | The full path of an existing file, relative to the importing module's directory, or `null`. |
| `JqFileResolver.open(canonicalPath: string): string` | Reads the file as UTF-8. |

## Errors

| Symbol | Description |
| --- | --- |
| `class JqError extends Error` | An uncaught run-time error; also the base of the two below. `name` is `"JqError"`. |
| `new JqError(message: string, value?: JsonValue)` | Creates an error with a message and an optional value. |
| `JqError.value: JsonValue \| undefined` | The error value; `undefined` for a parse error. Read-only. |
| `class JqParseError extends JqError` | A syntax or binding error, thrown by `Jq.parse`. `name` is `"JqParseError"`. |
| `new JqParseError(message: string, line: number, column: number)` | Creates a parse error at a position. |
| `JqParseError.line: number` | The 1-based line, in the program or in the module the message names. Read-only. |
| `JqParseError.column: number` | The 1-based column, in code points. Read-only. |
| `class JqHaltError extends JqError` | `halt_error` ended the evaluation. `name` is `"JqHaltError"`. |
| `new JqHaltError(message: string, value: JsonValue, exitCode: number)` | Creates a halt error. |
| `JqHaltError.exitCode: number` | The exit code given to `halt_error`. Read-only. |

## Values

| Symbol | Description |
| --- | --- |
| `JsonValue` (*type*) | `null \| boolean \| number \| string \| JsonValue[] \| { [key: string]: JsonValue }`: a result. |
| `JsonInput` (*type*) | `null \| boolean \| number \| string \| readonly JsonInput[] \| ReadonlyMap<string, JsonInput> \| { readonly [key: string]: JsonInput \| undefined }`: an input or a variable value. |

How values cross the boundary is described in [Values](values.md).
