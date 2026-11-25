---
title: "Evaluating"
---

# Evaluating

A jq program reads one input value and produces a stream of zero or more output values. The Go API
parses the program into an `*jqlite.Expression`, then evaluates it on an input. It gives the
results as a slice, through a callback, or as a range-over-func sequence.

## One-shot evaluation

`jqlite.Evaluate(program, input, variables)` parses and evaluates in one call, as in the
[first example](readme.md#a-first-program). It uses the default [options](options.md), with no
module resolver, and parses the program on every call: use it for programs that run once.

## Parse once, evaluate many times

```go
package main

import (
	"fmt"
	"log"

	"github.com/devlooped/jqlite/go"
)

func main() {
	expression, err := jqlite.Parse(`.price * .quantity`)
	if err != nil {
		log.Fatal(err)
	}

	for _, text := range []string{`{"price":2.5,"quantity":4}`, `{"price":10,"quantity":3}`} {
		input, err := jqlite.ParseJSON(text)
		if err != nil {
			log.Fatal(err)
		}
		results, err := expression.Evaluate(input, nil)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(jqlite.ToJSON(results[0]))
	}
}
```

```text
10
30
```

Parsing does all the static work once: the syntax, the binding of every name (an unknown function
such as `foo/0 is not defined`, a `break` without its `label`), and the loading of every module the
program imports. Any of these failures is a `*jqlite.ParseError`, returned before any evaluation;
see [Errors](errors.md).

There are three ways to parse:

| Function | Options |
| --- | --- |
| `Parse(expression)` | the defaults (the zero `Options`) |
| `ParseWithResolver(expression, resolver)` | the defaults, with a module resolver |
| `ParseWithOptions(expression, options)` | any `Options` |

`MustParse(expression)` is `Parse` that panics on an error, for programs written in your source
code. The options apply to every evaluation. The empty program (`""`) is `.`: it outputs its input.

## All results or a stream

`Expression.Evaluate` collects every result into a `[]jqlite.Value`. When an error reaches the top
of the program, it returns `nil` results and the error, even if some results came before it.

`Expression.EvaluateFunc` gives each result to a callback as soon as it is produced. The callback
returns `false` to stop the evaluation; stopping is not an error. This makes infinite programs
usable:

```go
package main

import (
	"fmt"
	"log"

	"github.com/devlooped/jqlite/go"
)

func main() {
	expression := jqlite.MustParse(`range(1; infinite) | select(. % 7 == 0)`)

	count := 0
	err := expression.EvaluateFunc(jqlite.Null, nil, func(v jqlite.Value) bool {
		fmt.Println(jqlite.ToJSON(v))
		count++
		return count < 3 // false stops the evaluation
	})
	if err != nil {
		log.Fatal(err)
	}
}
```

```text
7
14
21
```

With `EvaluateFunc`, earlier results have already reached the callback when an error is returned.
`Expression.Results` is the same stream as an `iter.Seq2[jqlite.Value, error]` for a `range` loop.
Each result comes with a `nil` error; an error that reaches the top of the program comes last, with
`jqlite.Null`. Breaking out of the loop stops the evaluation:

```go
package main

import (
	"fmt"

	"github.com/devlooped/jqlite/go"
)

func main() {
	expression := jqlite.MustParse(`.[] | 10 / .`)
	input, _ := jqlite.ParseJSON(`[1, 2, 0, 5]`)

	for v, err := range expression.Results(input, nil) {
		if err != nil {
			fmt.Println("error:", err)
			break
		}
		fmt.Println(jqlite.ToJSON(v))
	}
}
```

```text
10
5
error: number (10) and number (0) cannot be divided because the divisor is zero
```

A panic in the callback or in the loop body propagates to the caller of `EvaluateFunc` or
`Results`.

## One input per evaluation

An evaluation has exactly one input value. jqlite has no `input` or `inputs` builtins: a program that
calls them fails to parse with `input/0 is not defined`. To process several values, evaluate the
expression on each of them; for a JSON Lines stream, use [`Lines`](jsonl.md).

## Concurrency

An `*Expression` is immutable. Evaluate it from as many goroutines as you like at the same time,
each evaluation with its own input and variables:

```go
package main

import (
	"fmt"
	"sync"

	"github.com/devlooped/jqlite/go"
)

func main() {
	expression := jqlite.MustParse(`. * $factor`)

	results := make([]string, 4)
	var group sync.WaitGroup
	for i := range results {
		group.Go(func() {
			variables := map[string]jqlite.Value{"factor": jqlite.Number(10)}
			out, err := expression.Evaluate(jqlite.Number(float64(i)), variables)
			if err != nil {
				results[i] = err.Error()
				return
			}
			results[i] = jqlite.ToJSON(out[0])
		})
	}
	group.Wait()
	fmt.Println(results)
}
```

```text
[0 10 20 30]
```

Each evaluation keeps all its state to itself, and values are immutable, so inputs and results can
be shared between goroutines.

> [!NOTE]
> The `Options` are shared by every evaluation of the expression: the `Debug` and `Stderr` handlers
> and, for `modulemeta`, the resolver can be called from several goroutines at once. In a deep
> recursion (every 10,000 interpreter frames) an evaluation continues on a new goroutine while the
> calling one waits, so your callback can run on another goroutine, though never on two at once.
