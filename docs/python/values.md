---
title: "Values"
---

# Values

Inputs, variables and results are Python JSON values: what `json.loads` returns. jqlite has seven kinds of values (`null`, `false`, `true`, numbers, strings, arrays, objects; [spec §4.1](../language/spec.md#41-kinds)). This page says how each Python value becomes a jqlite value on the way in, and what Python value each jqlite value becomes on the way out.

## Summary

| jqlite | Python in | Python out |
| --- | --- | --- |
| `null` | `None` | `None` |
| `true`, `false` | `True`, `False` | `True`, `False` |
| number | `int`, `float` | `int` or `float` (below) |
| string | `str` | `str` |
| array | `list`, `tuple` | `list` |
| object | `dict`, any `Mapping` with `str` keys | `dict` |

Any other Python value raises `TypeError` before the evaluation starts:

```python
import jqlite

for value in [object(), {1: 2}, {"a": {1, 2} }]:
    try:
        jqlite.evaluate(".", value)
    except TypeError as e:
        print(e)
```

```text
object is not a JSON value
object keys must be strings, not int
set is not a JSON value
```

Conversion works with loops, not recursion: a value 10,000 levels deep goes in and comes out.

## Numbers

Every jqlite number is an IEEE 754 double. On the way in, an `int` becomes the nearest `float`; an `int` too large for a double becomes positive or negative infinity. `bool` stays a boolean, never a number.

On the way out, a number becomes what `json.loads` would read from its canonical text ([spec §5.2](../language/spec.md#52-number-formatter)):

- a number with no fractional part and a magnitude below 1e21 is an `int` (`-0` is `0`);
- any other number is a `float`;
- NaN is `None`;
- positive and negative infinity are `1.7976931348623157e+308` and `-1.7976931348623157e+308`, the largest doubles.

```python
import jqlite

print(jqlite.evaluate("[1.0, 1.5, 1e20, 1e21, -0, 1 / 3]", None))
print(jqlite.evaluate("[nan, infinite, -infinite]", None))
print(jqlite.evaluate(". + 1", 2**53 + 1))
```

```text
[[1, 1.5, 100000000000000000000, 1e+21, 0, 0.3333333333333333]]
[[None, 1.7976931348623157e+308, -1.7976931348623157e+308]]
[9007199254740992]
```

The last line shows the precision of a double: `2**53 + 1` has no exact double, so it goes in as `2**53`. Pass large integer identifiers as strings if you need every digit.

## Strings

A jqlite string is a sequence of Unicode code points, like a Python `str`. `length`, indexes and slices count code points. Python allows a `str` to hold a lone surrogate (a code point from U+D800 to U+DFFF that is not part of a pair); jqlite does not. A lone surrogate in a string or in an object key becomes U+FFFD, the replacement character, on the way in:

```python
import jqlite

print(jqlite.evaluate("explode", "a\ud800b"))  # [[97, 65533, 98]]
print(jqlite.evaluate("length", "héllo"))      # [5]
```

## Arrays and objects

A `list` or a `tuple` becomes an array; a `dict`, or any other `Mapping` whose keys are all `str`, becomes an object. Results are always `list` and `dict`.

Objects keep the insertion order of their keys, both ways. Input keys keep the order of the mapping; keys a program adds come after the existing ones. `keys` sorts; `keys_unsorted`, `to_entries` and `tojson` keep the order:

```python
import jqlite

print(jqlite.evaluate(".c = 3", {"b": 1, "a": 2}))  # [{'b': 1, 'a': 2, 'c': 3}]
print(jqlite.evaluate("keys", {"b": 1, "a": 2}))    # [['a', 'b']]
print(jqlite.evaluate("tojson", {"b": 1, "a": 2}))  # ['{"b":1,"a":2}']
```

Equality of objects ignores key order: `{"a":1,"b":2} == {"b":2,"a":1}` is `true`.

## Ownership and mutability

An evaluation converts its input and its variables once, when it starts. It does not keep or modify your objects: you can change or drop them as soon as `evaluate` or `stream` has returned, and a change made by a callback during `stream` does not reach the running evaluation.

Every result is a new tree of Python objects. It shares nothing with the input, with other results, or with another evaluation, even when the program outputs the same value twice. You own it and can change it:

```python
import jqlite

source = {"a": [1]}
result = jqlite.evaluate(".a", source)[0]
result.append(2)
print(source, result)  # {'a': [1]} [1, 2]

twice = jqlite.evaluate("[1] as $x | [$x, $x]", None)[0]
print(twice[0] is twice[1])  # False
```

Inside the engine, values are immutable and shared between threads; they never reach your code. The values passed to the `debug` and `stderr` handlers and the `value` of an exception are converted the same way as results.
