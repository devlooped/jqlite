---
title: "JSON Lines"
---

# JSON Lines

[JSON Lines](https://jsonlines.org) is a text format with one JSON value per line, common for logs
and exports. `Jq.evaluateLines` evaluates a parsed expression on each value of such a stream, in
order, and gives every result to a callback. It is synchronous: this port has no asynchronous or
reactive helper (the reference's `IAsyncEnumerable` and `IObservable` helpers are not ported).

## Reading a file

Take `events.jsonl`:

```json
{"user": "ada", "event": "login", "ms": 120}
{"user": "bob", "event": "error", "ms": 3400}

{"user": "ada", "event": "error", "ms": 15}
```

This program prints a line for each error event:

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqExpression;
import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

public class Lines {
    public static void main(String[] args) throws IOException {
        JqExpression errors = Jq.parse("select(.event == \"error\") | \"\\(.user): \\(.ms) ms\"");

        try (BufferedReader reader = Files.newBufferedReader(Path.of("events.jsonl"), StandardCharsets.UTF_8)) {
            Jq.evaluateLines(errors, reader, Map.of(), result -> {
                System.out.println(result.asString());
                return true;
            });
        }
    }
}
```

```text
bob: 3400 ms
ada: 15 ms
```

## The helper

```java
public static void evaluateLines(JqExpression expression, Reader jsonLines,
    Map<String, JqValue> variables, Predicate<JqValue> onResult) throws IOException
```

- `expression` is parsed once, before the call, and reused for every value. Its
  [options](options.md) apply to each evaluation.
- `jsonLines` is read line by line (it is wrapped in a `BufferedReader` unless it is one). Blank
  lines are skipped. The caller opens and closes the reader.
- `variables` are the [host variables](variables.md) of every evaluation; `Map.of()` or `null` for
  none.
- `onResult` receives each result as it is produced. It returns `true` to continue and `false` to
  stop: the current evaluation stops and no further line is read.

Each line must hold exactly one JSON value. A value cannot span lines.

## Each value alone

Each value is evaluated alone, as if `evaluate` were called once per line: nothing of one
evaluation reaches the next. `halt` ends only the evaluation of its own value, and the next line is
then evaluated. To combine values across lines, such as a sum or a count, compute it in Java from
the results, or collect the values into one array and evaluate the program once on it.

## Errors

The first error stops the whole stream:

| Case | Exception |
| --- | --- |
| a line that is not one JSON value (`{bad`, `1 2`) | `JqException` from the JSON reader: `Unexpected extra JSON values (while parsing '1 2')` |
| an uncaught error in the evaluation of a value | `JqException`, as for `evaluate` ([Errors](errors.md)) |
| `halt_error` | `JqHaltException` |
| reading the `Reader` fails | `IOException` |
| the callback throws | its exception, unchanged |

The results of the earlier lines, and those of the failing value before its error, have already
been given to `onResult`. To skip bad values instead of stopping, catch the error in the program:
`try (.x + $k) catch empty`.

## Without the helper

`evaluateLines` is a short loop over `JqJson.parse` and `JqExpression.evaluate`. Write your own
when the values come from somewhere else (a queue, a socket) or when one bad line should not stop
the others:

```java
JqExpression names = Jq.parse(".user");
for (String line : List.of("{\"user\": \"ada\"}", "not json", "{\"user\": \"bob\"}")) {
    try {
        for (JqValue result : names.evaluate(JqJson.parse(line))) {
            System.out.println(JqJson.toJson(result));
        }
    } catch (JqException e) {
        System.err.println("skipped: " + e.getMessage());
    }
}
```

The parsed expression is safe to share between threads, so the values can also be evaluated in
parallel: see [Threads](evaluate.md#threads).
