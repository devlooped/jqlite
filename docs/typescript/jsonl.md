---
title: "JSON Lines"
---

# JSON Lines

jqlite evaluates a program on one value at a time: it has no `input` or `inputs`. To process a
stream of values, such as a [JSON Lines](https://jsonlines.org) file, the API runs one evaluation per
value with `Jq.evaluateAsync`.

## Jq.evaluateAsync

```typescript
import { Jq } from "@devlooped/jqlite";

for await (const result of Jq.evaluateAsync(".a * 10", [{ a: 1 }, { a: 2 }, { a: 3 }])) {
  console.log(result);
}
```

```text
10
20
30
```

```typescript
Jq.evaluateAsync(expression: string | JqExpression, inputs: AsyncIterable<JsonInput> | Iterable<JsonInput>, variables?: JqVariables): AsyncGenerator<JsonValue, void, undefined>
```

- `expression` is a program text, parsed with the default [options](options.md), or a parsed
  `JqExpression` with options of its own.
- `inputs` is any iterable or async iterable of [values](values.md): an array, a generator, a stream
  of parsed lines.
- `variables` are the [host variables](variables.md), the same for every value.

It yields the results of the first value, then those of the second, and so on. The results of one
value are all computed before the first of them is yielded. Each value is evaluated alone, as
`evaluate` does: nothing of one evaluation reaches the next, and `halt` ends only the evaluation of
its own value.

```typescript
import { Jq } from "@devlooped/jqlite";

const results = [];
for await (const result of Jq.evaluateAsync("if . == 2 then halt else ., . * 10 end", [1, 2, 3])) {
  results.push(result);
}
console.log(results);
```

```text
[ 1, 10, 3, 30 ]
```

An error is different: the first value whose evaluation throws ends the iteration, and the `for
await` loop throws that `JqError`. To go on past a bad value, catch the error in the program
(`try ... catch`, see [Errors](errors.md)). A string expression is parsed when the iteration starts,
so its `JqParseError` too comes out of the loop, not out of the call.

## Reading a .jsonl file

Given `events.jsonl`:

```text
{"user": "ada", "action": "login", "ms": 120}
{"user": "alan", "action": "upload", "ms": 3400}
{"user": "ada", "action": "upload", "ms": 2100}
```

```typescript
import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";
import { Jq, type JsonInput } from "@devlooped/jqlite";

async function* values(path: string): AsyncGenerator<JsonInput> {
  const lines = createInterface({ input: createReadStream(path, "utf8"), crlfDelay: Infinity });
  for await (const line of lines) {
    if (line.trim() !== "") yield JSON.parse(line) as JsonInput;
  }
}

const slow = Jq.parse("select(.ms > $limit) | {user, ms}");

for await (const result of Jq.evaluateAsync(slow, values("events.jsonl"), { limit: 1000 })) {
  console.log(JSON.stringify(result));
}
```

```text
{"user":"alan","ms":3400}
{"user":"ada","ms":2100}
```

The lines are read one at a time: the file is never held in memory whole. `JSON.parse` makes plain
objects, so keys that look like array indexes lose their order (see
[key order](values.md#key-order)).

## Reusing a parsed expression

Pass a `JqExpression` to parse the program once for the whole stream, and to give it options. The
same expression can serve several streams, one after the other or interleaved.

For exact key order, or to write JSON Lines out, call `evaluateText` per line instead. It takes the
JSON text and returns the canonical text of each result, without going through plain objects:

```typescript
import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";
import { Jq } from "@devlooped/jqlite";

const users = Jq.parse("select(.action == \"upload\") | .user");
const lines = createInterface({ input: createReadStream("events.jsonl", "utf8"), crlfDelay: Infinity });

for await (const line of lines) {
  if (line.trim() === "") continue;
  for (const text of users.evaluateText(line)) process.stdout.write(text + "\n");
}
```

```text
"alan"
"ada"
```

`evaluateText` throws a `JqError` for a line that is not exactly one JSON value.

There is no synchronous helper for a stream: for an array already in memory, call `evaluate` on
each element.
