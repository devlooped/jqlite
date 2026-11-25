---
title: "Evaluating"
---

# Evaluating

A jqlite program runs on one input value and produces zero or more results. The Java API gives
two ways to run it: `Jq.evaluate` for a single use, and `Jq.parse` with `JqExpression.evaluate`
for a program you run many times.

## One-shot evaluation

```java
JqValue input = JqJson.parse("{\"name\": \"Ada\", \"langs\": [\"en\", \"fr\"]}");
List<JqValue> results = Jq.evaluate(".name, .langs[]", input);
// "Ada", "en", "fr"
```

`Jq.evaluate(String, JqValue)` parses the program with the default [options](options.md),
evaluates it and returns all the results in order. `Jq.evaluate(String, JqValue, Map)` also takes
[host variables](variables.md). Both parse the program again on every call.

## Parse once, evaluate many times

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqExpression;
import com.devlooped.jqlite.JqJson;
import com.devlooped.jqlite.values.JqValue;

public class Reuse {
    public static void main(String[] args) {
        JqExpression total = Jq.parse("[.items[] | .price * .qty] | add");

        for (String json : new String[] {
            "{\"items\": [{\"price\": 2.5, \"qty\": 4}]}",
            "{\"items\": [{\"price\": 1, \"qty\": 3}, {\"price\": 10, \"qty\": 1}]}",
        }) {
            JqValue result = total.evaluate(JqJson.parse(json)).get(0);
            System.out.println(JqJson.toJson(result));
        }
    }
}
```

```text
10
13
```

`Jq.parse` reads the program and binds it: every function, variable pattern, label and module is
resolved before any evaluation. These are checked at parse time and throw `JqParseException`:

- syntax errors (`.a +` is `Unexpected end of program at line 1, column 5`);
- calls of unknown functions (`totl/0 is not defined`), including `input` and `inputs`, which
  jqlite does not have;
- `break $name` without a visible `label $name`, and `$alias::name` without its data import;
- modules: a module not found, a cycle of imports, an error inside a module (see [Modules](modules.md)).

A `$name` with no binding is not a parse error: it is a host variable, looked up when it is
evaluated (see [Variables](variables.md)). Run-time errors are described in [Errors](errors.md).

`Jq.parse(String, JqOptions)` takes [options](options.md) that apply to every evaluation of the
expression; `Jq.parse(String, JqResolver)` is the default options with a [module resolver](modules.md).
A null program, options or resolver throws `NullPointerException`.

## All results or a stream

`evaluate(input)` and `evaluate(input, variables)` run the program to its end and return a
`List<JqValue>` of all the results. If an error reaches the top of the program, they throw and
return nothing.

The overloads with a `Predicate<JqValue>` give each result to the callback as soon as it is
produced. The callback returns `true` to continue and `false` to stop; stopping is not an error.

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqExpression;
import com.devlooped.jqlite.JqJson;
import com.devlooped.jqlite.values.JqValue;
import java.util.ArrayList;
import java.util.List;

public class FirstSquares {
    public static void main(String[] args) {
        JqExpression squares = Jq.parse("range(1000000000) | . * .");
        List<JqValue> firstThree = new ArrayList<>();
        squares.evaluate(JqValue.NULL, result -> {
            firstThree.add(result);
            return firstThree.size() < 3;
        });
        firstThree.forEach(v -> System.out.println(JqJson.toJson(v)));
    }
}
```

```text
0
1
4
```

The program stops after the third result: the rest of the range is never computed. When an error
reaches the top of a streamed evaluation, the results produced before it have already been given
to the callback, then the exception is thrown. An exception thrown by the callback itself ends the
evaluation and reaches the caller of `evaluate`.

## One input per evaluation

An evaluation has exactly one input value. jqlite has no `input` or `inputs` (a program that uses
them fails to parse with `input/0 is not defined`), and nothing of one evaluation reaches the
next. To process a stream of values, evaluate the program on each value: [JSON Lines](jsonl.md)
shows the helper that does it.

The empty program is `.`: `Jq.evaluate("", input)` returns the input. A program made only of
comments or of definitions (`def f: 1;`) is also `.`. A program that produces nothing, such as
`empty`, returns an empty list.

## Threads

A `JqExpression` is immutable. One instance can be evaluated from many threads at once, each
evaluation with its own input and variables:

```java
JqExpression scale = Jq.parse("map(. * $k) | add");
JqValue input = JqJson.parse("[1, 2, 3]");

List<String> sums = IntStream.range(0, 8).parallel()
    .mapToObj(k -> scale.evaluate(input, Map.of("k", JqValue.fromNumber(k))).get(0))
    .map(JqJson::toJson)
    .toList();
// [0, 6, 12, 18, 24, 30, 36, 42]
```

Values are immutable too, so the same input can be shared between evaluations. Parse a program
once and keep the `JqExpression`, for example in a static field.

> [!NOTE]
> A deep recursion does not exhaust the caller's stack. When an evaluation goes deeper than the
> budget of its thread, it continues on a thread of the pool `jqlite-stack-N` (64 MB of stack)
> while the caller waits. The callbacks (`onResult`, `debug`, `stderr`, a resolver called by
> `modulemeta`) then run on that thread, without the caller's thread-locals, and an exception they
> throw comes back to the caller. Interrupting the caller does not stop such an evaluation: return
> `false` from `onResult` to stop it. See the [port notes](port.md) and [the depth limit](options.md#the-depth-limit).
