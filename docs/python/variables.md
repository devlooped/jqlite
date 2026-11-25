---
title: "Variables"
---

# Variables

A program can read values that the host passes beside the input, as `$name`. This is how you give a program parameters without building its text from strings ([spec §7.5](../language/spec.md#75-variables-and-bindings)).

## Passing variables

Both `jqlite.evaluate` and `Expression.evaluate` (and `Expression.stream`) take a `variables` mapping. Its keys are the names without `$`, its values Python JSON values ([Values](values.md)):

```python
import jqlite

print(jqlite.evaluate("[$a, $b]", None, {"a": "A", "b": [1, 2]}))  # [['A', [1, 2]]]

expression = jqlite.parse(".price * $rate")
for rate in (1, 1.21):
    print(expression.evaluate({"price": 100}, {"rate": rate}))
```

```text
[['A', [1, 2]]]
[100]
[121]
```

The variables belong to one evaluation. A parsed expression does not remember them: each call gives its own, and the values are converted once per call. `variables=None` (the default) passes none.

`$root` is an ordinary host variable: `{"root": ...}` binds it.

```python
import jqlite

print(jqlite.evaluate("{name, id: $root.id}", {"name": "Alice"}, {"root": {"id": 42} }))
# [{'name': 'Alice', 'id': 42}]
```

## Rules for names

A name is a jq identifier without `$`: a letter (`A` to `Z`, `a` to `z`) or `_`, then letters, digits and `_`. Only ASCII counts. The name `ENV` is not allowed: `$ENV` is the environment, set with [`Options.environment`](options.md#environment).

The names are checked before the evaluation starts. A bad name raises `ValueError`, and nothing of the program runs:

```python
import jqlite

for name in ["$x", "a-b", "ENV"]:
    try:
        jqlite.evaluate(".", None, {name: 1})
    except ValueError as e:
        print(e)
```

```text
'$x' is not a valid variable name: give a jq identifier without '$'.
'a-b' is not a valid variable name: give a jq identifier without '$'.
$ENV cannot be a host variable: use Options.environment.
```

A value that is not a JSON value raises `TypeError`, as an input does.

## A variable the host does not supply

A `$name` that has no binding in the program is not a parse error. It is looked up when it is evaluated. If the host did not supply it, the result is the run-time error `$name is not defined`, raised as `jqlite.JqError` ([Errors](errors.md)). It is an ordinary error, so `try` catches it:

```python
import jqlite

expression = jqlite.parse("$x + 1")
print(expression.evaluate(None, {"x": 1}))  # [2]

try:
    expression.evaluate(None)
except jqlite.JqError as e:
    print(e)  # $x is not defined

print(jqlite.evaluate('try $x catch "no x"', None))  # ['no x']
print(jqlite.evaluate("$x // 0", None, {"x": None}))  # [0]
```

A program that never evaluates `$x` runs without it: `if false then $x else 1 end` gives `1`.

The same holds inside a module: an unbound `$name` in a module is the same host variable as in the main program ([Modules](modules.md)). A qualified `$alias::name` is different: it must be bound by a data import, otherwise `parse` raises `JqParseError`.

## Shadowing

Bindings in the program win over host variables of the same name, by lexical scope. Both `as $name` and `$name` parameters of a function shadow a host variable:

```python
import jqlite

print(jqlite.evaluate("2 as $x | $x", None, {"x": 1}))        # [2]
print(jqlite.evaluate("def f($x): $x; f(3)", None, {"x": 1}))  # [3]
print(jqlite.evaluate("def f(y): $x; f(3)", None, {"x": 1}))   # [1]
```

In the last line, `f` has no `$x` parameter, so `$x` is the host variable.

## Predefined names

Two names are not host variables:

- `$ENV` is an object of the environment variables: [`Options.environment`](options.md#environment), or the process environment by default. A program can shadow it with its own binding.
- `$__loc__` is not a variable but a location: the object `{"file": F, "line": L}`, where `L` is the line of the `$` and `F` is `"<top-level>"` in the main program, or the module's canonical path in a module.

```python
import jqlite

print(jqlite.evaluate("$__loc__", None))  # [{'file': '<top-level>', 'line': 1}]
```
