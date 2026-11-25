---
title: "Errors"
---

# Errors

Every failure comes back as a Go `error` of one of four types. Use `errors.As` to tell them apart.

| Type | Returned by | When |
| --- | --- | --- |
| `*jqlite.ParseError` | `Parse`, `ParseWithResolver`, `ParseWithOptions`, `Evaluate`, `EvaluateLines` | a syntax or binding error, before any evaluation |
| `*jqlite.Error` | the evaluation methods | an error that no `try` caught |
| `*jqlite.HaltError` | the evaluation methods | `halt_error` |
| `*jqlite.VariableError` | the evaluation methods | an invalid host variable name |

`MustParse` panics with the `*ParseError` instead of returning it.

```go
package main

import (
	"errors"
	"fmt"

	"github.com/devlooped/jqlite/go"
)

func run(program string) {
	_, err := jqlite.Evaluate(program, jqlite.Null, nil)

	var parseError *jqlite.ParseError
	var jqError *jqlite.Error
	var haltError *jqlite.HaltError
	switch {
	case err == nil:
		fmt.Println("ok")
	case errors.As(err, &parseError):
		fmt.Printf("parse error at %d:%d: %s\n", parseError.Line, parseError.Column, parseError.Message)
	case errors.As(err, &jqError):
		fmt.Printf("error %s: %s\n", jqlite.ToJSON(jqError.Value), jqError.Message)
	case errors.As(err, &haltError):
		fmt.Printf("halt_error, exit code %d: %s\n", haltError.ExitCode, haltError.Message)
	}
}

func main() {
	run(`.a |`)
	run(`{} | .a.b.c = 1 | .a.b + 1`)
	run(`error({code: 42})`)
	run(`"stopped" | halt_error(2)`)
	run(`1, halt, 2`)
}
```

```text
parse error at 1:5: Unexpected end of program at line 1, column 5
error "object ({\"c\":1}) and number (1) cannot be added": object ({"c":1}) and number (1) cannot be added
error {"code":42}: {"code":42} (not a string)
halt_error, exit code 2: stopped
ok
```

## Syntax and binding errors

A `*ParseError` is returned when the program text is not valid jqlite, or when a name cannot be
bound: an unknown function (`foo/0 is not defined`), a `break` without its label
(`$*label-x is not defined`), a missing module (`module not found: x`), a program nested too deeply.

- `Message` is the error followed by its place: `<message> at line L, column C`, or
  `<message> at <module>, line L, column C` when the error is inside a module.
- `Line` and `Column` start at 1; columns count code points.
- `Module` is the canonical path of the module where the error is, or `""` for the program itself.

`Error()` returns `Message`. A program that uses `input` or `inputs` gets a `*ParseError` too: jqlite
does not have them.

## Run-time errors

A `*jqlite.Error` is an error raised while the program runs and not caught by `try`: one raised by
`error(v)`, or by a builtin (`Cannot index array with string ("a")`, `Maximum call depth exceeded`,
`$name is not defined`...).

- `Value` is the error value. Any value can be an error value; a builtin's error is its message
  string.
- `Message` is the value when it is a string. Otherwise it is the value's JSON text followed by
  ` (not a string)`; NaN inside it is written `null`.

`Evaluate` returns `nil` results with the error. `EvaluateFunc` and `Results` deliver the results
produced before the error first. The messages of the builtins are listed in
[the spec](../language/spec.md#103-runtime-errors).

## halt and halt_error

`halt` ends the evaluation normally: the results produced before it are returned, with a `nil`
error. `halt_error` and `halt_error(code)` end it with a `*jqlite.HaltError`:

- `Value` is the input of `halt_error`.
- `ExitCode` is the code: 5 for `halt_error`, the truncated argument for `halt_error(code)`.
- `Message` follows the same rule as for `*Error`.

Nothing in a program can catch `halt` or `halt_error`. The package never exits the process: what
to do with `ExitCode` is up to you.

## Catching errors inside the program

`try body catch handler` runs `handler` on the error value when `body` fails; the outputs of `body`
before the error are kept. `try body` and `body?` drop the error.

```jq
[.[] | try (if . < 0 then error({negative: .}) else . * 2 end) catch .negative]
```

On the input `[1, -3, 4]`, this program outputs `[2,-3,8]`. Errors that `try` handles never reach
Go. `try` does not catch `break`, `halt` or `halt_error`; see
[the spec](../language/spec.md#713-try-catch-and-).

## Invalid arguments

A host variable name that is not a jq identifier, or that is `ENV`, makes the evaluation methods
return a `*jqlite.VariableError` before the program runs; its `Name` field is the bad key. See
[Variables](variables.md#names).

`ParseJSON` returns a plain error, with jq's message for invalid JSON. `FromAny` returns a plain
error for a Go value it cannot convert. The `As...` accessors of `Value` panic when called on a
value of another kind: that is a bug in the calling code, not a jqlite error.
