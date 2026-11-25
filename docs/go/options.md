---
title: "Options"
---

# Options

`jqlite.Options` holds what a program takes from its host besides its input and variables. Pass it
to `ParseWithOptions`. The options are read when the program is parsed and apply to every
evaluation of the resulting expression. The zero `Options` are the defaults, which `Parse` uses.

## Summary

| Field | Type | Default (zero value) | Effect |
| --- | --- | --- | --- |
| `Resolver` | `Resolver` | `nil`: no module exists | `import`, `include`, `modulemeta`; see [Modules](modules.md) |
| `Environment` | `[]string` | `nil`: the process environment | `$ENV` and `env` |
| `Now` | `func() time.Time` | `nil`: `time.Now` | `now` |
| `Location` | `*time.Location` | `nil`: `time.Local` | the local zone of `localtime`, `strflocaltime`, `%z`, `%Z` |
| `MaxDepth` | `int` | `0`: 1000 | the maximum depth of calls of jq-defined functions |
| `Debug` | `func(Value)` | `nil`: values dropped | receives what `debug` and `debug(msg)` emit |
| `Stderr` | `func(Value)` | `nil`: values dropped | receives what `stderr` emits |

`ParseWithResolver(expression, resolver)` is `ParseWithOptions` with only `Resolver` set.

## Environment

`Environment` is the content of `$ENV` (and of `env`), as `NAME=value` entries: the form of
`os.Environ()`. The object keeps the order of the entries. An entry without `=` is a name with an
empty value; a repeated name keeps its first position and its last value.

- `nil` (the default): the process environment, read with `os.Environ()` by each evaluation that
  uses `$ENV`.
- An empty, non-nil slice (`[]string{}`): `$ENV` is `{}`.
- Any other slice: copied when the program is parsed; later changes to the slice have no effect.

## Clock and time zone

`Now` is the source of `now`; the result is converted to seconds since the Unix epoch, with the
fraction. `Location` is the local zone used by `localtime`, `strflocaltime`, and the `%z` and `%Z`
directives. Daylight saving time follows the date being formatted. `%Z`
prints the zone's name as Go gives it (`time.Time.Zone`); when the zone has no name, it prints the
offset, such as `-03`.

```go
package main

import (
	"fmt"
	"log"
	"time"

	"github.com/devlooped/jqlite/go"
)

func main() {
	options := jqlite.Options{
		Environment: []string{"STAGE=test", "REGION=eu"},
		Now:         func() time.Time { return time.Date(2025, 1, 15, 12, 0, 0, 0, time.UTC) },
		Location:    time.FixedZone("ART", -3*60*60),
	}
	expression, err := jqlite.ParseWithOptions(`$ENV, env.STAGE, now, (now | strflocaltime("%H:%M %z %Z"))`, options)
	if err != nil {
		log.Fatal(err)
	}
	results, err := expression.Evaluate(jqlite.Null, nil)
	if err != nil {
		log.Fatal(err)
	}
	for _, r := range results {
		fmt.Println(jqlite.ToJSON(r))
	}
}
```

```text
{"STAGE":"test","REGION":"eu"}
"test"
1736942400
"09:00 -0300 ART"
```

> [!NOTE]
> The spec describes a host without a clock, where `now` is an error and the local zone is UTC.
> The Go API always has one: without `Now` and `Location`, it uses the system clock and
> `time.Local`. Set `Location: time.UTC` for results that do not depend on the machine.

The directives of `strftime` and `strptime` are listed in
[the spec](../language/spec.md#912-broken-down-time-and-directives).

## The depth limit

`MaxDepth` is the maximum number of calls of jq-defined functions (yours and those of the prelude)
active at the same time. Zero or a negative value means the default, 1000. There is no upper bound
other than memory. One call level takes about 1.6 to 2.5 KB, so `MaxDepth: 100000` can use
160 to 250 MB.

Past the limit, the evaluation fails with the run-time error `Maximum call depth exceeded`, which
`try` can catch. A recursion never crashes the process: deep recursion continues on fresh
goroutines instead of overflowing one stack.

```go
package main

import (
	"fmt"

	"github.com/devlooped/jqlite/go"
)

func main() {
	program := `def count: if . == 0 then 0 else (. - 1 | count) + 1 end; count`
	expression, _ := jqlite.ParseWithOptions(program, jqlite.Options{MaxDepth: 100})

	for _, n := range []float64{99, 100} {
		results, err := expression.Evaluate(jqlite.Number(n), nil)
		fmt.Println(results, err)
	}
}
```

```text
[99] <nil>
[] Maximum call depth exceeded
```

There are no tail calls: every active call counts. How calls are counted, and why a program should
not depend on the exact depth, is in [the spec](../language/spec.md#11-limits). The other limits of
the spec (program nesting 1000, JSON nesting 10000, ...) are fixed.

## Debug and stderr handlers

`debug` outputs its input unchanged and gives it to `Debug`; `debug(msg)` gives each output of
`msg` instead. `stderr` outputs its input unchanged and gives it to `Stderr`. The handlers receive
the values as they are; they are not formatted as jq's command line formats them. Without a
handler, the values are dropped.

```go
package main

import (
	"fmt"
	"log"

	"github.com/devlooped/jqlite/go"
)

func main() {
	options := jqlite.Options{
		Debug:  func(v jqlite.Value) { fmt.Println("debug:", jqlite.ToJSON(v)) },
		Stderr: func(v jqlite.Value) { fmt.Println("stderr:", jqlite.ToJSON(v)) },
	}
	expression, err := jqlite.ParseWithOptions(`debug | debug("got", .a) | stderr | .a + 1`, options)
	if err != nil {
		log.Fatal(err)
	}
	input, _ := jqlite.ParseJSON(`{"a":1}`)
	results, err := expression.Evaluate(input, nil)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(jqlite.ToJSON(results[0]))
}
```

```text
debug: {"a":1}
debug: "got"
debug: 1
stderr: {"a":1}
2
```

The handlers are shared by every evaluation of the expression: when you evaluate it from several
goroutines, they are called concurrently.
