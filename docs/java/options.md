---
title: "Options"
---

# Options

`JqOptions` holds what an expression takes from its host besides the input and the variables. It
is immutable: `JqOptions.defaults()` returns the defaults, and each `with...` method returns a copy
with one option changed. The options are given to `Jq.parse(String, JqOptions)` and apply to every
evaluation of the expression it returns.

| Option | Method | Default | Effect |
| --- | --- | --- | --- |
| Module resolver | `withResolver(JqResolver)` | `null`: no module exists | `import`, `include`, `modulemeta` ([Modules](modules.md)) |
| Environment | `withEnvironment(Map<String, String>)` | `null`: the process environment | `$ENV` and `env` |
| Clock | `withClock(Clock)` | `Clock.systemDefaultZone()` | `now` and the local time zone |
| Depth limit | `withMaxDepth(int)` | `1000` | calls of jqlite functions active at once, 1 to 100,000 |
| `debug` handler | `withDebug(Consumer<JqValue>)` | `null`: values dropped | receives the values of `debug` |
| `stderr` handler | `withStderr(Consumer<JqValue>)` | `null`: values dropped | receives the values of `stderr` |

Each option has a getter of the same name: `resolver()`, `environment()`, `clock()`, `maxDepth()`,
`debug()`, `stderr()`.

## Environment

```java
Map<String, String> environment = new LinkedHashMap<>();
environment.put("APP_MODE", "test");
environment.put("REGION", "eu");
JqOptions options = JqOptions.defaults().withEnvironment(environment);

Jq.parse("$ENV, env.REGION", options).evaluate(JqValue.NULL)
    .forEach(v -> System.out.println(JqJson.toJson(v)));
```

```text
{"APP_MODE":"test","REGION":"eu"}
"eu"
```

`$ENV` and `env` are an object of strings, its keys in the iteration order of the map.
`withEnvironment` copies the map: changing it afterwards has no effect. `withEnvironment(null)`
restores the default, the process environment (`System.getenv()`), read again by each evaluation
that uses `$ENV`. To give a program no environment at all, pass `Map.of()`.

## Clock and time zone

```java
Clock clock = Clock.fixed(Instant.parse("2015-03-05T23:51:47Z"), ZoneId.of("Europe/Berlin"));
JqExpression times = Jq.parse(
    "now, (now | todate), (now | strflocaltime(\"%Y-%m-%d %H:%M:%S %z %Z\"))",
    JqOptions.defaults().withClock(clock));
times.evaluate(JqValue.NULL).forEach(v -> System.out.println(JqJson.toJson(v)));
```

```text
1425599507
"2015-03-05T23:51:47Z"
"2015-03-06 00:51:47 +0100 +01"
```

The clock is a `java.time.Clock`. Its instant is `now`, in seconds since the epoch with the
fraction of its nanoseconds. Its zone is the local time zone of `localtime`, `strflocaltime`,
`mktime` of local times and the directives `%z` and `%Z`. The offset is taken at each instant, so
daylight saving time follows the date: with the zone `Europe/Berlin`, `1435708800 |
strflocaltime("%H:%M %z")` is `"02:00 +0200"`.

- `%Z` prints the offset (`+01`), not a zone abbreviation such as `CET`: this port, like the
  reference, has no zone abbreviations.
- `gmtime`, `todate` and `strftime` use UTC and do not depend on the zone.
- The default is the system clock in the default zone of the JVM. `withClock(null)` throws
  `NullPointerException`: there is no option without a clock. Use `Clock.fixed` for repeatable
  results, in tests for example.

## The depth limit

```java
JqExpression down = Jq.parse(
    "def down: if . == 0 then \"bottom\" else (. - 1 | down) end; down",
    JqOptions.defaults().withMaxDepth(100));

down.evaluate(JqValue.fromNumber(99));   // ["bottom"]
down.evaluate(JqValue.fromNumber(100));  // throws JqException: Maximum call depth exceeded
```

`maxDepth` is the largest number of calls of functions written in jqlite (yours and the prelude's)
that are active at once ([spec §11](../language/spec.md#11-limits)). There are no tail calls. Past
the limit, the evaluation raises the error `Maximum call depth exceeded`. It is an ordinary error:
a program catches it with `try`, and uncaught it is a `JqException`. The process is never at risk.

- The default is `1000`.
- `withMaxDepth` accepts 1 to `JqOptions.MAX_DEPTH_LIMIT` (100,000) and throws
  `IllegalArgumentException` otherwise.
- A level of recursion takes about 2 KB of thread stack, up to 4 KB. A deep evaluation continues on
  threads of 64 MB stacks while the caller waits, so 100,000 levels may take up to 400 MB.

See the [threads note](evaluate.md#threads) for where callbacks run after such a hop.

## Debug and stderr

```java
JqOptions logging = JqOptions.defaults()
    .withDebug(value -> System.err.println("debug: " + JqJson.toJson(value)))
    .withStderr(value -> System.err.println("stderr: " + JqJson.toJson(value)));

Jq.parse(".a | debug | debug(\"twice: \" + (. * 2 | tostring)) | stderr | . + 1", logging)
    .evaluate(JqJson.parse("{\"a\": 5}"));   // [6]
```

This writes to standard error:

```text
debug: 5
debug: "twice: 10"
stderr: 5
```

`debug` gives its input to the debug handler, and `debug(msg)` gives each message; `stderr` gives
its input to the stderr handler. The values are passed as they are: jqlite does not wrap them as
jq's `["DEBUG:", v]`. All three output their input unchanged. Without a handler the values are
dropped. A handler runs on the thread of the evaluation, while it waits; an exception it throws
ends the evaluation and reaches the caller.
