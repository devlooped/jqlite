---
title: "JSON Lines"
---

# JSON Lines

A JSON Lines file holds one JSON value per line. jqlite runs one evaluation per value: each value is the input of its own evaluation, and nothing of one evaluation reaches the next. The package has two helpers for this, `jqlite.evaluate_each` for an iterable of values and `jqlite.evaluate_each_async` for an asynchronous one. They take values, not text: decoding the lines (with `json.loads`) is yours.

## Synchronous streams

`evaluate_each(expression, inputs, variables=None)` is a generator. It evaluates `expression` on each value of `inputs` in turn and yields the results:

```python
import json
import tempfile
from pathlib import Path
import jqlite

lines = [
    '{"name": "Alice", "age": 30, "active": true}',
    '{"name": "Bob", "age": 25, "active": false}',
    '{"name": "Carol", "age": 41, "active": true}',
]

with tempfile.TemporaryDirectory() as folder:
    path = Path(folder) / "people.jsonl"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    with path.open(encoding="utf-8") as f:
        values = (json.loads(line) for line in f if line.strip())
        for name in jqlite.evaluate_each("select(.active) | .name", values):
            print(name)
```

```text
Alice
Carol
```

- `inputs` is read lazily, one value at a time: the file above is never loaded whole.
- The results of one value are all computed before the first of them is yielded (each value runs through `Expression.evaluate`).
- `variables` apply to every evaluation.
- An error raises from the generator ([Errors](errors.md)) and ends it: the values after the one that failed are not evaluated.
- `halt` ends only the evaluation of its value; the next value is evaluated as usual.

```python
import jqlite

print(list(jqlite.evaluate_each("if . == 2 then halt else . end", [1, 2, 3])))  # [1, 3]
```

To go on after an error, catch it inside the program with `try`, or loop yourself over the values and catch `jqlite.JqError` around each `Expression.evaluate`.

## Reusing a parsed expression

`expression` is a `str` or an `Expression`. A string is parsed once per call of `evaluate_each`, with the default options; `evaluate_each` has no `options` parameter. To use options (a resolver, an environment, a depth limit), or to run the same program over several streams, parse it yourself and pass the `Expression`:

```python
import jqlite

options = jqlite.Options(environment={"CURRENCY": "EUR"})
expression = jqlite.parse('{id, price: "\\(.price) \\($ENV.CURRENCY)"}', options)

for batch in ([{"id": 1, "price": 10}], [{"id": 2, "price": 7.5}]):
    for result in jqlite.evaluate_each(expression, batch):
        print(result)
```

```text
{'id': 1, 'price': '10 EUR'}
{'id': 2, 'price': '7.5 EUR'}
```

A string `expression` that does not parse raises `JqParseError` when the generator starts, at the first `next()`, not when `evaluate_each` is called.

## Asynchronous streams

`evaluate_each_async(expression, inputs, variables=None)` takes an asynchronous iterable of values and is an asynchronous generator:

```python
import asyncio
import jqlite

async def values():
    for age in (30, 25):
        await asyncio.sleep(0)
        yield {"age": age}

async def main():
    async for result in jqlite.evaluate_each_async(".age * 2", values()):
        print(result)

asyncio.run(main())
```

```text
60
50
```

Only the source is asynchronous. Each evaluation runs synchronously on the event loop's thread, between two values of the source: a long evaluation blocks the loop while it runs. To keep the loop free, run `Expression.evaluate` in a worker thread with `asyncio.to_thread` ([Evaluating](evaluate.md#threads)).
