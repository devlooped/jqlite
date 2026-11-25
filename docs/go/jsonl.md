---
title: "JSON Lines"
---

# JSON Lines

[JSON Lines](https://jsonlines.org) is text with one JSON value per line, as in log files and data
exports. `Expression.Lines` reads such a stream from an `io.Reader` and evaluates the expression on
each value in turn. `jqlite.EvaluateLines` does the same for a program given as a string. Both
return an `iter.Seq2[jqlite.Value, error]` for a `range` loop. The package has no channel-based or
`context`-aware variant: run the loop on a goroutine of your own if you need one.

## Reading a file

With an `events.jsonl` file holding:

```json
{"level":"info","message":"started"}
{"level":"error","message":"disk full"}

{"level":"error","message":"retrying"}
```

this program prints the messages of the errors:

```go
package main

import (
	"fmt"
	"log"
	"os"

	"github.com/devlooped/jqlite/go"
)

func main() {
	file, err := os.Open("events.jsonl")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	expression := jqlite.MustParse(`select(.level == $level) | .message`)
	variables := map[string]jqlite.Value{"level": jqlite.String("error")}

	for result, err := range expression.Lines(file, variables) {
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(result.AsString())
	}
}
```

```text
disk full
retrying
```

The expression is parsed once and evaluated on each line, with the same variables. Reuse one
parsed expression across files and goroutines as you would with `Evaluate`; see
[Evaluating](evaluate.md#parse-once-evaluate-many-times).

## How the stream is read

- Each line holds one JSON value. Leading and trailing white space is trimmed, so `\r\n` line ends
  work. Blank lines are skipped.
- A line can be up to 1 GiB long.
- Each value is evaluated alone, as by `Evaluate`: nothing of one evaluation reaches the next.
  `halt` ends the evaluation of its value only; the next line is evaluated as usual.
- All the results of one value are computed before the first of them is yielded.
- Breaking out of the loop stops reading.

## Errors

The sequence ends at the first error, which is yielded with `jqlite.Null`:

| Error | Example |
| --- | --- |
| a line that is not one JSON value | `jqlite: line 2: Object keys must be strings at line 1, column 2 (while parsing '{x')` |
| a run-time error of the program | a `*jqlite.Error`, such as `Cannot index array with string ("a")` |
| `halt_error` | a `*jqlite.HaltError` |
| an invalid variable name | a `*jqlite.VariableError`, when the first value is evaluated |
| an error of the reader | the reader's error |

The error of a bad line wraps the `ParseJSON` error with the line number (`%w`). The results of the
earlier lines have already been yielded. To skip bad values instead of stopping, read the lines
yourself and call `Evaluate` on each.

## One-shot form

`EvaluateLines(expression, reader, variables)` parses the program with the default options, then
behaves like `Lines`. If the program does not parse, the `*jqlite.ParseError` is the first and only
element of the sequence:

```go
for result, err := range jqlite.EvaluateLines(`.id`, os.Stdin, nil) {
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(jqlite.ToJSON(result))
}
```

To use [options](options.md), such as a module resolver, parse with `ParseWithOptions` and call
`Lines` on the expression.
