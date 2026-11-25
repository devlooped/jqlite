---
title: "jqlite for Go"
---

# jqlite for Go

The Go port of jqlite is a library that runs jq programs on JSON values from Go code. It is a
file-by-file port of the .NET reference engine: it follows the same [specification](../language/spec.md)
and passes the same conformance corpus (`spec/tests`). The package `jqlite` is the host API; the
engine lives in `internal/` and is not importable.

## Requirements

- Go 1.26 or later (the `go` directive of `go/go.mod`).
- No dependency outside the standard library.

## Getting the package

The module path is `github.com/devlooped/jqlite/go` and the package name is `jqlite`:

```go
import "github.com/devlooped/jqlite/go"
```

The repository has no release tags for the Go module (a module in the `go/` folder would need tags
of the form `go/vX.Y.Z`). Use it from a clone of the repository with a `replace` directive in your
own `go.mod`:

```shell-session
$ git clone https://github.com/devlooped/jqlite
$ cd myapp
$ go mod edit -require=github.com/devlooped/jqlite/go@v0.0.0 -replace=github.com/devlooped/jqlite/go=../jqlite/go
```

The embedded prelude (`go/internal/binding/prelude.jq`) is committed, so no `go generate` step is
needed to build against the clone. How to build and test the port itself: [the port's README](port.md).

## A first program

```go
package main

import (
	"fmt"
	"log"

	"github.com/devlooped/jqlite/go"
)

func main() {
	input, err := jqlite.ParseJSON(`{"items":[{"name":"apple","price":5},{"name":"pear","price":15}]}`)
	if err != nil {
		log.Fatal(err)
	}

	results, err := jqlite.Evaluate(`.items[] | select(.price > 10) | {name, price}`, input, nil)
	if err != nil {
		log.Fatal(err)
	}
	for _, result := range results {
		fmt.Println(jqlite.ToJSON(result))
	}
}
```

```text
{"name":"pear","price":15}
```

`ParseJSON` turns JSON text into a `jqlite.Value`. `Evaluate` parses the program, runs it on the
input and returns every result. The third argument holds the host variables (`nil` for none).
`ToJSON` writes a result as compact JSON text.

A program can give zero, one or many results, so results always come as a slice or a stream. To run
the same program many times, parse it once with `Parse` and keep the `*jqlite.Expression`: see
[Evaluating](evaluate.md).

## In this section

| Page | What it covers |
| --- | --- |
| [Evaluating](evaluate.md) | One-shot evaluation, parse once and evaluate many times, streaming, concurrency |
| [Values](values.md) | `jqlite.Value`: building inputs, reading results, numbers, strings, key order |
| [Variables](variables.md) | Host variables (`$name`), `$ENV`, `$__loc__` |
| [Options](options.md) | Environment, clock and time zone, depth limit, `debug` and `stderr` handlers |
| [Modules](modules.md) | `import`, `include`, data modules, `modulemeta` and resolvers |
| [Errors](errors.md) | `ParseError`, `Error`, `HaltError`, `VariableError`, and `try` in programs |
| [JSON Lines](jsonl.md) | Evaluating a program on each value of a JSON Lines stream |
| [API reference](api.md) | Every exported identifier of the package |
| [The port](port.md) | Build, tests, layout and differences from the reference |

The language itself is described in [the language guide](../language/readme.md); the differences
from jq 1.8 are listed in [the spec](../language/spec.md#13-differences-from-jq-18).
