---
title: "Options"
---

# Options

Options are what a program takes from its host besides its input and its variables. They are the
second argument of `Jq.parse`, of type `JqOptions`; every field is optional.

| Option | Type | Default | Effect |
| --- | --- | --- | --- |
| `resolver` | `JqResolver` | none: no module exists | finds the modules of `import`, `include` and `modulemeta` (see [Modules](modules.md)) |
| `environment` | `Readonly<Record<string, string>>` or `ReadonlyMap<string, string>` | `process.env` where there is one, else empty | the object of `$ENV` and `env` |
| `clock` | `JqClock` | the system clock and zone, from `Date` | `now`, and the local zone of `localtime`, `strflocaltime`, `%z`, `%Z` |
| `maxDepth` | `number` | `1000` | the most calls of jq-defined functions active at once |
| `debug` | `(value: JsonValue) => void` | none: values dropped | receives the values of `debug` |
| `stderr` | `(value: JsonValue) => void` | none: values dropped | receives the values of `stderr` |

Options are read when the expression is parsed and apply to every evaluation of it. To evaluate
with other options, parse again. `Jq.evaluate` and `Jq.evaluateAsync` with a string use the
defaults.

## Environment

```typescript
import { Jq } from "@devlooped/jqlite";

const expression = Jq.parse("$ENV, env.A", { environment: { B: "2", A: "1" } });
console.log(JSON.stringify(expression.evaluate(null)));
```

```text
[{"B":"2","A":"1"},"1"]
```

The object keeps the order of the plain object or `Map` given (with the [key order](values.md#key-order)
caveat of plain objects). It is copied when the expression is parsed: later changes to the object
given do not show. Entries whose value is `undefined` are left out.

Without the option, `$ENV` is Node's `process.env`, read by each evaluation the first time it uses
`$ENV` or `env`. Where there is no `process` (a browser), `$ENV` is `{}`. To give a program no
environment at all, pass `environment: {}`.

## Clock and time zone

```typescript
import { Jq, type JqClock } from "@devlooped/jqlite";

// 2015-03-05T23:51:47Z, in a zone five and a half hours east of UTC.
const clock: JqClock = { now: () => 1425599507, offset: () => 19800 };
const expression = Jq.parse('now, (now | strflocaltime("%H:%M %z %Z")), (now | strftime("%H:%M %Z"))', { clock });
console.log(expression.evaluate(null));
```

```text
[ 1425599507, '05:21 +0530 +0530', '23:51 UTC' ]
```

A `JqClock` has three members:

| Member | Meaning |
| --- | --- |
| `now(): number` | the current time, in seconds since the Unix epoch; a fraction is allowed |
| `offset(seconds: number): number` | the offset of the local zone at that instant, in seconds east of UTC; a fraction is truncated |
| `abbreviation?(seconds: number): string \| null` | optional: the zone's name at that instant, for `%Z` |

Without an abbreviation, `%Z` in local time prints the offset: `+hh`, or `+hhmm` when the minutes
are not 0. In UTC (`strftime`, `todate`) it prints `UTC`.

The default clock is the system's: `now` is `Date.now() / 1000`, and the offset at an instant comes
from `Date`, so it follows the daylight saving time of the process's zone. JavaScript gives no zone
abbreviation that does not depend on a locale, so the default clock has none. The default always
exists: there is no way to run without a clock.

Pass a fixed clock to make results reproducible, in tests for example. The rules of the date
builtins are in [spec §9.12](../language/spec.md#912-broken-down-time-and-directives).

## The depth limit

`maxDepth` limits the number of calls of jq-defined functions active at once: your own `def`s and
the builtins written in jqlite (`map`, `select`, `limit` and many others). There are no tail calls:
every active call counts. Past the limit, the evaluation raises the run-time error
`Maximum call depth exceeded`, which `try` catches like any other error.

```typescript
import { Jq, JqError } from "@devlooped/jqlite";

const count = Jq.parse("def f: if . == 0 then 0 else (. - 1 | f) + 1 end; f", { maxDepth: 10 });
console.log(count.evaluate(9));
try {
  count.evaluate(10);
} catch (e) {
  if (e instanceof JqError) console.log(e.message);
}
```

```text
[ 9 ]
Maximum call depth exceeded
```

`N | f` above makes `N + 1` calls of `f`, so `9` fits in 10 and `10` does not.

No recursion uses the JavaScript stack: the interpreter keeps its own stack on the heap. The limit
can therefore be raised as far as memory allows; the tests run recursions 1,000,000 calls deep.
Up to the limit, a program never fails with a `RangeError`.

The value is not checked. Give a positive integer: with `0` or less, every call of a jq-defined
function fails, and with `NaN` or `Infinity` there is no limit.

The spec's account of depth is in [spec §11](../language/spec.md#11-limits).

## Debug and stderr

```typescript
import { Jq, type JsonValue } from "@devlooped/jqlite";

const logged: JsonValue[] = [];
const expression = Jq.parse('debug, debug("m", {a: .}), stderr', {
  debug: (value) => logged.push(value),
  stderr: (value) => logged.push(["stderr", value]),
});
console.log(JSON.stringify(expression.evaluate(1)), JSON.stringify(logged));
```

```text
[1,1,1] [1,"m",{"a":1},["stderr",1]]
```

`debug` outputs its input unchanged and gives the handler that input; `debug(msgs)` gives the
handler each output of `msgs`. `stderr` outputs its input and gives it to its handler. The handlers
receive the values as they are: there is no `["DEBUG:", v]` wrapper as in the jq command line.
Without a handler, the values are dropped and the filters still output their input.

A handler runs during the evaluation, synchronously. An exception it throws propagates out of the
evaluation.
