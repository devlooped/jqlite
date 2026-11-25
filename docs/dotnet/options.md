---
title: "Options"
---

# Options

[JqOptions](xref:JQLite.JqOptions) holds what a program gets from its host besides its input and
its [variables](variables.md). Pass it to `Jq.Parse(expression, options)`: the options are read
when the expression is parsed and apply to every evaluation of it. `Jq.Evaluate`, `Jq.Parse(expression)`
and `Jq.EvaluateAsync(string, …)` use the defaults.

| Option | Type | Default | Used by |
| --- | --- | --- | --- |
| `Resolver` | [JqResolver](xref:JQLite.JqResolver)? | `null`: no module exists | `import`, `include`, `modulemeta` (see [Modules](modules.md)) |
| `Environment` | `IReadOnlyDictionary<string, string>?` | `null`: the process environment | `$ENV`, `env` |
| `TimeProvider` | `TimeProvider` | `TimeProvider.System` | `now`; the local time zone of `localtime`, `strflocaltime`, `%z`, `%Z` |
| `MaxDepth` | `int` | `1000` | the calls of jqlite functions active at once |
| `Debug` | `Action<JsonElement>?` | `null`: values are dropped | `debug`, `debug(msg)` |
| `Stderr` | `Action<JsonElement>?` | `null`: values are dropped | `stderr` |

The properties are `init`-only: create a new `JqOptions` for other settings. One instance can be
shared by any number of expressions.

## Environment

`$ENV` and `env` are an object of string values. With `Environment` set, they are that dictionary,
with its keys in the dictionary's order. The dictionary is copied when the expression is parsed:
later changes to it do not reach the expression.

```csharp
using System.Text.Json;
using JQLite;

var options = new JqOptions
{
    Environment = new Dictionary<string, string> { ["STAGE"] = "prod", ["REGION"] = "eu" },
};

using var doc = JsonDocument.Parse("null");
foreach (var result in Jq.Parse("$ENV, env.STAGE", options).Evaluate(doc.RootElement))
    Console.WriteLine(result.GetRawText());
// {"STAGE":"prod","REGION":"eu"}
// "prod"
```

With `Environment` left `null`, `$ENV` is the environment of the process, read when an evaluation
first uses `$ENV` or `env` (once per evaluation). An empty dictionary gives an empty object: use it
to keep the process environment away from programs you do not trust.

## Clock and time zone

`TimeProvider` is the source of `now` (`GetUtcNow()`) and of the local time zone
(`LocalTimeZone`) of `localtime`, `strflocaltime`, and the `%z` and `%Z` directives. The offset of
the zone is taken at each instant, so daylight saving time follows the date. `gmtime`,
`strftime`, `todate` and the other UTC builtins do not use the zone.

```csharp
using System.Text.Json;
using JQLite;

var options = new JqOptions
{
    TimeProvider = new FixedTime(
        new DateTimeOffset(2025, 6, 1, 12, 0, 0, TimeSpan.Zero),
        TimeZoneInfo.CreateCustomTimeZone("UTC-3", TimeSpan.FromHours(-3), "UTC-3", "UTC-3")),
};

using var doc = JsonDocument.Parse("null");
var expression = Jq.Parse("""now, (now | todate), (now | strflocaltime("%H:%M %z %Z"))""", options);
foreach (var result in expression.Evaluate(doc.RootElement))
    Console.WriteLine(result.GetRawText());
// 1748779200
// "2025-06-01T12:00:00Z"
// "09:00 -0300 -03"

class FixedTime(DateTimeOffset now, TimeZoneInfo zone) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => now;

    public override TimeZoneInfo LocalTimeZone => zone;
}
```

.NET has no time zone abbreviations, so `%Z` in local time prints the offset: `-03` above, or
hours and minutes (`+0530`) when the minutes are not 0. In UTC (`strftime`), `%Z` prints `UTC`. Dates use the English
names of jqlite's own tables, never the current culture.

## The depth limit

`MaxDepth` limits the number of calls of functions written in jqlite (yours and the builtins
defined in the prelude, such as `map`) that are active at the same time. Past it, the evaluation
raises the error `Maximum call depth exceeded`. It is an ordinary run-time error: `try` catches
it, and uncaught it is a [JqException](xref:JQLite.JqException).

```csharp
using System.Text.Json;
using JQLite;

var countdown = Jq.Parse(
    "def f: if . == 0 then 0 else (. - 1 | f) + 1 end; f",
    new JqOptions { MaxDepth = 10 });

using var nine = JsonDocument.Parse("9");
using var ten = JsonDocument.Parse("10");

Console.WriteLine(countdown.Evaluate(nine.RootElement)[0]); // 9

try
{
    countdown.Evaluate(ten.RootElement);
}
catch (JqException ex)
{
    Console.WriteLine(ex.Message); // Maximum call depth exceeded
}
```

- Every call counts while it is active: there are no tail calls. `N | f` above makes `N + 1`
  nested calls, so the default of 1000 allows `999 | f`.
- The limit is the only one a program meets: up to it, recursion never overflows the .NET stack,
  even on a thread with a small stack, and past it the error is always `Maximum call depth exceeded`,
  never a crash.
- The value is not validated. With `0` or a negative value, the first call of a jqlite function
  fails; operators and native builtins (`1 + 1`, `length`) still work.
- Builtins implemented natively do not count, and `range`, `limit` and other generators have no
  length limit.

See spec [§11](../language/spec.md#11-limits) for the other limits, which are fixed: 1000 levels of
nesting in the program text, 10000 levels when reading JSON.

## Debug and stderr

`debug` and `stderr` output their input unchanged, and hand a value to your handler. Without a
handler, the value is dropped; nothing is written to the console.

```csharp
using System.Text.Json;
using JQLite;

var options = new JqOptions
{
    Debug = value => Console.Error.WriteLine($"debug: {value.GetRawText()}"),
    Stderr = value => Console.Error.WriteLine($"stderr: {value.GetRawText()}"),
};

using var doc = JsonDocument.Parse("1");
var results = Jq.Parse("""debug, debug("m", {a: .}), stderr""", options).Evaluate(doc.RootElement);
Console.WriteLine(string.Join(",", results.Select(r => r.GetRawText())));
// standard error: debug: 1, debug: "m", debug: {"a":1}, stderr: 1
// standard output: 1,1,1
```

- `Debug` receives the input of each `debug`, and each message of `debug(msgs)`, as is. The jq
  command line writes `["DEBUG:",1]`; the handler gets `1`, without the wrapper.
- `Stderr` receives the input of each `stderr`.

A handler runs synchronously, on the thread of the evaluation, when the program reaches the
builtin. An exception it throws ends the evaluation and reaches the caller of `Evaluate`
unchanged.
