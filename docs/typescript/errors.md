---
title: "Errors"
---

# Errors

The API throws three error classes of its own, all subclasses of `JqError` (itself an `Error`), and
`TypeError` for invalid arguments.

| Class | Thrown by | When |
| --- | --- | --- |
| `JqParseError` | `Jq.parse`, `Jq.evaluate`, `Jq.evaluateAsync` with a string | a syntax or binding error, before any evaluation |
| `JqError` | the evaluation methods | an error that no `try` caught reached the top of the program |
| `JqHaltError` | the evaluation methods | `halt_error` ended the evaluation |
| `TypeError` | every method | an argument that is not what the API takes |

## Syntax and binding errors

```typescript
import { Jq, JqParseError } from "@devlooped/jqlite";

try {
  Jq.parse(".a |\n  foo");
} catch (e) {
  if (e instanceof JqParseError) console.log(e.message, e.line, e.column);
}
```

```text
foo/0 is not defined at line 2, column 3 2 3
```

`line` and `column` are 1-based; the column counts code points. The message ends with the position:
` at line L, column C`, or ` at <module>, line L, column C` when the error is inside a
[module](modules.md), where `<module>` is its canonical path and the position is in the module's
text. `value` is `undefined`.

Besides syntax errors, binding errors are found here: an unknown function (`foo/0 is not defined`),
a `break` without its `label` (`$*label-x is not defined`), a `$alias::name` without its data
import, a module that cannot be found or read, a circular import, and a program nested more than
1,000 levels deep (`Program too deeply nested`).

## Run-time errors

```typescript
import { Jq, JqError } from "@devlooped/jqlite";

for (const program of ['error("boom")', "error({code: 42})", '. + 1']) {
  try {
    Jq.evaluate(program, "a");
  } catch (e) {
    if (e instanceof JqError) console.log(e.message, "|", JSON.stringify(e.value));
  }
}
```

```text
boom | "boom"
{"code":42} (not a string) | {"code":42}
string ("a") and number (1) cannot be added | "string (\"a\") and number (1) cannot be added"
```

`value` is the error value: what `error(v)` raised, or the message of a builtin's error. Any JSON
value can be an error value. The message is the value itself when it is a string, else its JSON
text followed by ` (not a string)`. The messages of the builtins are listed in
[spec §10](../language/spec.md#10-errors).

`evaluate` returns nothing when it throws. `evaluateEach` has already given its callback the results
produced before the error. `Maximum call depth exceeded` (see [the depth limit](options.md#the-depth-limit))
and `$name is not defined` (see [Variables](variables.md)) are run-time errors like the others.

## Catching errors in the program

`try B catch H` catches an error raised by `B` and runs `H` on the error value; `try B` drops it;
`B?` is `try B`. Results of `B` before the error are kept.

```typescript
import { Jq } from "@devlooped/jqlite";

console.log(JSON.stringify(Jq.evaluate("[try (1, error(\"x\"), 3) catch .]", null)));
console.log(JSON.stringify(Jq.evaluate("[.[] | .a?]", [{ a: 1 }, true, { a: 2 }])));
```

```text
[[1,"x"]]
[[1,2]]
```

Every run-time error is catchable, including `Maximum call depth exceeded`. `break`, `halt` and
`halt_error` are not errors: `try` does not catch them. The rules are in
[spec §7.13](../language/spec.md#713-try-catch-and-).

## Halting

`halt` ends the evaluation normally: no more results, no error. `halt_error` ends it with a
`JqHaltError`, whose `value` is the input of `halt_error` and `exitCode` its code (`5` by default).
The message follows the same rule as other errors.

```typescript
import { Jq, JqHaltError } from "@devlooped/jqlite";

console.log(Jq.evaluate("1, halt, 2", null));
try {
  Jq.evaluate('"bye" | halt_error(3)', null);
} catch (e) {
  if (e instanceof JqHaltError) console.log(e.message, e.exitCode);
}
```

```text
[ 1 ]
bye 3
```

`JqHaltError` is a `JqError`: test for it first when both are handled. With `evaluateEach`, the
results before the halt have been given to the callback.

## Invalid arguments

These are `TypeError`s, thrown before anything is evaluated:

- an expression that is not a string;
- an input or a variable value that is not JSON (a function, a symbol, a `bigint`, `undefined`
  itself, a `Map` with a key that is not a string; see [Values](values.md));
- a variable name that is not a jq identifier, or `ENV` (see [Variables](variables.md)).

Exceptions thrown by your own code (an `evaluateEach` callback, a `debug` or `stderr` handler)
propagate unchanged. Exceptions thrown by a resolver become parse errors, or run-time errors for
`modulemeta`.
