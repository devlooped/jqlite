---
title: "Variables"
---

# Variables

A program can read values that the host passes in as variables, written `$name` in the program.
This is how you give a program parameters without building the program text yourself (the jq
command line does the same with `--arg` and `--argjson`).

## Passing variables

Every evaluation method takes a `map[string]jqlite.Value` of variables; pass `nil` for none.

```go
package main

import (
	"fmt"
	"log"

	"github.com/devlooped/jqlite/go"
)

func main() {
	expression := jqlite.MustParse(`.[] | select(.age >= $min) | "\(.name) (\($root.team))"`)

	input, _ := jqlite.ParseJSON(`[{"name":"Ann","age":34},{"name":"Bo","age":17}]`)
	variables := map[string]jqlite.Value{
		"min":  jqlite.Number(18),
		"root": jqlite.NewObject(jqlite.Member{Key: "team", Value: jqlite.String("blue")}),
	}

	results, err := expression.Evaluate(input, variables)
	if err != nil {
		log.Fatal(err)
	}
	for _, r := range results {
		fmt.Println(jqlite.ToJSON(r))
	}
}
```

```text
"Ann (blue)"
```

The same parsed expression can be evaluated with different variables each time, from several
goroutines at once. The map is only read; any value, of any kind, can be a variable.

## Names

A key of the map is the variable's name without the `$`: `"min"` binds `$min`, `"root"` binds
`$root`. A name must be a jq identifier, `[A-Za-z_][A-Za-z0-9_]*`. `ENV` is not allowed, because
`$ENV` is the environment (see below).

The names are checked before the evaluation starts. An invalid name is a `*jqlite.VariableError`
whose `Name` field holds the key:

```text
jqlite: '$x' is not a valid variable name: give a jq identifier without '$'
jqlite: $ENV cannot be a host variable: use Options.Environment
```

> [!NOTE]
> The one-shot `jqlite.Evaluate(expression, input, variables)` parses the program first, so a
> syntax error is reported before an invalid variable name. `Lines` checks the names when it
> evaluates the first value of the stream.

## A variable the host does not supply

A `$name` that no `as $name` or parameter binds, and that is not `$ENV` or `$__loc__`, is a host
variable. It is looked up when it is evaluated, not when the program is parsed. If the map has no
such key, the evaluation fails with the run-time error `$name is not defined`, which a program can
catch:

```jq
try $limit catch "no limit"
```

Without a `$limit` variable, this program outputs `"no limit"`. Without `try`, `$limit` alone
makes `Evaluate` return a `*jqlite.Error` with the message `$limit is not defined`.

The same holds inside [modules](modules.md): a module's unbound `$name` is the same host variable
as in the main program. A qualified name such as `$data::x` is different: it must be bound by a data
import, or the program fails to parse.

## Shadowing

A binding in the program hides a host variable of the same name, inside its scope:

- `E as $name | B` binds `$name` in `B`. With `"x": 2` in the map, `1 | . as $x | $x` outputs `1`.
- A function parameter `$name` binds `$name` in the function's body. With `"x": 2` in the map,
  `def f($x): $x; f(3)` outputs `3`.

Outside those scopes, `$name` is the host variable again. The rules of scope are in
[the spec](../language/spec.md#75-variables-and-bindings).

## $ENV

`$ENV` is an object of the environment variables, and `env` returns the same object. It is not a
host variable: it comes from [`Options.Environment`](options.md#environment), the process environment
by default. A program can shadow `$ENV` with its own `as $ENV` binding.

## $__loc__

`$__loc__` is the source location of the place where it is written:

```jq
$__loc__
```

```json
{"file":"<top-level>","line":1}
```

`line` counts from 1. In a module, `file` is the module's canonical path, as the resolver gave it.
`$__loc__` is not a variable: it cannot be bound with `as` or used as a parameter name, and a
`"__loc__"` key in the map is accepted but never read.
