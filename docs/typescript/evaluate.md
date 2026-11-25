---
title: "Evaluating"
---

# Evaluating

A jqlite program is a filter: it takes one input value and produces zero, one or many results. The
API has one call that does everything at once, and a parsed expression for repeated use.

## One-shot evaluation

```typescript
import { Jq } from "@devlooped/jqlite";

console.log(Jq.evaluate(".[] | . * 2", [1, 2, 3]));
console.log(Jq.evaluate(".a", { b: 1 }));
console.log(Jq.evaluate("empty", null));
```

```text
[ 2, 4, 6 ]
[ null ]
[]
```

`Jq.evaluate(expression, input, variables?)` parses `expression` with the default
[options](options.md), evaluates it on `input` and returns an array of all its results. The third
argument holds the [host variables](variables.md). It parses the program on every call: use it for a
program that runs once.

## Parse once, evaluate many times

```typescript
import { Jq } from "@devlooped/jqlite";

const total = Jq.parse("map(.price * .count) | add");

console.log(total.evaluate([{ price: 3, count: 2 }]));
console.log(total.evaluate([{ price: 1, count: 9 }, { price: 2, count: 1 }]));
```

```text
[ 6 ]
[ 11 ]
```

`Jq.parse(expression, options?)` returns a `JqExpression`. Parsing does all the work that does not
depend on the input:

- the syntax is checked;
- every name is bound: an unknown function (`foo/0 is not defined`), a `break` without its `label`
  and a `$alias::name` without its data import are errors here, not during evaluation;
- the modules of `import` and `include` are loaded through the resolver (see [Modules](modules.md));
- the [options](options.md) are read and fixed for every evaluation of the expression.

Each of these failures throws a `JqParseError` with a line and a column (see [Errors](errors.md)).
A `$name` that is not bound in the program is not a parse error: it is a host variable, looked up
when evaluated (see [Variables](variables.md)).

An empty program, or one with only whitespace and comments, is the identity `.`:

```typescript
import { Jq } from "@devlooped/jqlite";

console.log(Jq.evaluate("# nothing but a comment", { a: 1 }));
```

```text
[ { a: 1 } ]
```

## All results or a stream

`evaluate` computes every result before it returns. `evaluateEach` gives each result to a callback
as soon as it is produced; the callback returns `true` to go on and `false` to stop:

```typescript
import { Jq, type JsonValue } from "@devlooped/jqlite";

const seen: JsonValue[] = [];
Jq.parse("range(1e9)").evaluateEach(null, (n) => {
  seen.push(n);
  return seen.length < 3;
});
console.log(seen);
```

```text
[ 0, 1, 2 ]
```

`range(1e9)` is lazy: stopping after three results costs three steps, not a billion. Stopping is not
an error. Other differences between the two:

- When an error reaches the top of the program, `evaluate` throws and returns nothing;
  `evaluateEach` has already given the results produced before the error, then throws.
- An exception thrown by the callback propagates out of `evaluateEach` unchanged and ends the
  evaluation.

A third method, `evaluateText(input, variables?)`, takes the input as JSON text and returns the
canonical JSON text of each result. It is the way to keep the exact key order of objects (see
[Values](values.md#key-order)).

## One input per evaluation

An evaluation has exactly one input value. jqlite has no `input` or `inputs`: a program that uses
them fails to parse with `input/0 is not defined`. To run a program on a sequence of values, run one
evaluation per value; [JSON Lines](jsonl.md) shows the helper that does it. Nothing of one
evaluation reaches the next: `halt` in one ends only that one.

## Concurrency

A `JqExpression` is immutable and holds no state of an evaluation. Every evaluation gets its own
input, variables and interpreter, so evaluations of one expression do not affect each other, even
when one starts while another is running: from an `evaluateEach` callback, or from a `debug`
handler.

```typescript
import { Jq } from "@devlooped/jqlite";

const square = Jq.parse(". * .");
Jq.parse(".[]").evaluateEach([2, 3], (n) => {
  console.log(n, square.evaluate(n));
  return true;
});
```

```text
2 [ 4 ]
3 [ 9 ]
```

JavaScript runs one thread at a time, and worker threads share no objects: a `JqExpression` cannot
be passed to a worker. Each worker parses the program itself; the tests run eight workers that
parse and evaluate the same program at once and get the same results.

Evaluation is synchronous: `evaluate` and `evaluateEach` block the thread until the program ends or
the callback stops it. A long evaluation holds the event loop for its whole run.
