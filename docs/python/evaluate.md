---
title: "Evaluating"
---

# Evaluating

An evaluation runs a jq program on one input value and produces a stream of output values. The package gives you three ways to run one: `jqlite.evaluate` for a single call, `Expression.evaluate` for a program you parsed once, and `Expression.stream` to receive the outputs one by one.

## One-shot evaluation

```python
import jqlite

print(jqlite.evaluate(".a + 1", {"a": 41}))           # [42]
print(jqlite.evaluate(".[] | .name", [{"name": "x"}, {"name": "y"}]))  # ['x', 'y']
```

`evaluate(expression, input, variables=None, options=None)` parses `expression`, evaluates it on `input` and returns a `list` of every output. The `variables` are described in [Variables](variables.md), the `options` in [Options](options.md).

Parsing has a cost. When you run the same program more than once, parse it once.

## Parse once, evaluate many times

```python
import jqlite

expression = jqlite.parse("[.[] | select(. > $min)]")

print(expression.evaluate([1, 5, 10], {"min": 4}))  # [[5, 10]]
print(expression.evaluate([1, 5, 10], {"min": 7}))  # [[10]]
```

`jqlite.parse(expression, options=None)` returns an `Expression`. Parsing does all the work that does not depend on the input:

- the syntax of the program is checked;
- every name is bound: an unknown function, a `break` without its `label`, or a `$alias::name` without its data import is an error now, not when the program runs;
- the modules that `import` and `include` name are loaded through the options' resolver and bound ([Modules](modules.md));
- the options are fixed: every evaluation of the expression uses the options given to `parse`.

Any of these problems raises `jqlite.JqParseError` with a line and a column ([Errors](errors.md)):

```python
import jqlite

try:
    jqlite.parse(".a |\n  foo")
except jqlite.JqParseError as e:
    print(e.line, e.column, e)  # 2 3 foo/0 is not defined at line 2, column 3
```

A `$name` with no binding in the program is not a parse error: it is a host variable, looked up when the program runs ([Variables](variables.md)). `parse` raises `TypeError` when `expression` is not a `str`.

The empty program, or one made only of comments and definitions, is the identity `.`:

```python
import jqlite

print(jqlite.evaluate("", [1]))           # [[1]]
print(jqlite.evaluate("def f: 1;", [1]))  # [[1]]
```

## All results or a stream

`Expression.evaluate(input, variables=None)` computes every output before it returns the list. A program with many outputs, or an endless one, needs `Expression.stream(input, on_result, variables=None)` instead. It calls `on_result` with each output as soon as it is produced:

```python
import jqlite

first = []

def take(result):
    first.append(result)
    return len(first) < 3  # False stops the evaluation

jqlite.parse("range(1000000000)").stream(None, take)
print(first)  # [0, 1, 2]
```

- When `on_result` returns `False` (exactly `False`), the evaluation stops. Stopping is not an error: `stream` returns normally. Any other return value, `None` included, lets it go on.
- When the program raises an error, `on_result` has already received every output produced before it; then `stream` raises the error.
- An exception raised by `on_result` propagates out of `stream` and ends the evaluation.
- `stream` returns `None`.

Inside a program, `limit` and `first` also stop early without the host's help: `[limit(3; repeat(1))]` gives `[1, 1, 1]`.

## One input per evaluation

An evaluation has exactly one input value. jqlite has no `input` or `inputs` builtins: a program that names them fails to parse with `input/0 is not defined`. To process several values, run one evaluation per value, with a loop or with `jqlite.evaluate_each` ([JSON Lines](jsonl.md)). Nothing of one evaluation reaches the next. See [the differences from jq](../language/spec.md#13-differences-from-jq-18).

## Threads

An `Expression` is immutable. You can evaluate one expression from many threads at once, each call with its own input and variables:

```python
import threading
import jqlite

expression = jqlite.parse("[.[] | . * $k] | add")
results = [None] * 8

def work(i):
    results[i] = expression.evaluate([1, 2, 3], {"k": i})[0]

threads = [threading.Thread(target=work, args=(i,)) for i in range(8)]
for t in threads:
    t.start()
for t in threads:
    t.join()
print(results)  # [0, 6, 12, 18, 24, 30, 36, 42]
```

Parsing different programs on different threads at once is also safe.

- The library starts no thread. The callbacks (`on_result`, the `debug` and `stderr` handlers, the methods of a resolver) run on the thread that called `parse`, `evaluate` or `stream`.
- A resolver used by `modulemeta` is called while the expression is evaluated, so it can be called from several threads at once ([Modules](modules.md)).
- The engine is pure Python: on a CPython build with the global interpreter lock, evaluations on several threads take turns on one core.

> [!NOTE]
> Deep recursion in a jq program becomes deep recursion in Python. While a parse or an evaluation runs, the library raises Python's recursion limit (`sys.setrecursionlimit`, a setting of the whole process) to what it may need. When the last parse or evaluation running on any thread ends, it puts the limit back. Your own code that runs meanwhile, callbacks included, sees the raised limit. Importing `jqlite` changes nothing.
