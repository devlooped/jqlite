---
title: "Options"
---

# Options

`jqlite.Options` holds what a program takes from its host besides the input and the variables. Pass it to `jqlite.parse` (or to `jqlite.evaluate`): the options are fixed when the expression is parsed and apply to every evaluation of it.

```python
import jqlite

options = jqlite.Options(environment={"STAGE": "test"}, max_depth=200, debug=print)
expression = jqlite.parse("$ENV.STAGE", options)
print(expression.evaluate(None))  # ['test']
```

## Summary

| Option | Type | Default | Effect |
| --- | --- | --- | --- |
| `resolver` | `Resolver` or `None` | `None` | finds the modules of `import`, `include` and `modulemeta`; without one, no module exists ([Modules](modules.md)) |
| `environment` | `Mapping[str, str]` or `None` | `None` | the variables of `$ENV` and `env`; `None` is the process environment |
| `clock` | `Clock` | `SystemClock()` | `now` and the local time zone |
| `max_depth` | `int`, 0 to 100,000 | `1000` | the most calls of jq functions active at once |
| `debug` | callable or `None` | `None` | receives the values of `debug`; `None` drops them |
| `stderr` | callable or `None` | `None` | receives the values of `stderr`; `None` drops them |

`Options` is a frozen dataclass: its fields cannot be changed after it is created. Use `dataclasses.replace(options, max_depth=50)` to derive a new one. The default of `parse` and `evaluate` (`options=None`) is `Options()`.

## Environment

`environment` gives the variables of `$ENV` and of `env` (the same object), keys and values as strings, in the order of the mapping:

```python
import jqlite

options = jqlite.Options(environment={"B": "2", "A": "1"})
print(jqlite.parse("$ENV, env.A", options).evaluate(None))  # [{'B': '2', 'A': '1'}, '1']
```

The mapping is copied when the expression is parsed: later changes to it are not seen. With `environment=None`, `$ENV` is `os.environ`, read again by each evaluation the first time it uses `$ENV` or `env`. Pass `environment={}` to hide the process environment from programs.

## Clock and time zone

`clock` is the source of `now` and of the local time zone used by `localtime`, `strflocaltime`, and the `%z` and `%Z` directives. Any object with these three methods is a clock (the `jqlite.Clock` protocol):

| Method | Returns |
| --- | --- |
| `now()` | the current time, in seconds since the Unix epoch (`float`) |
| `offset(seconds)` | the offset of the local zone from UTC at that instant, in seconds east of UTC (`int`) |
| `abbreviation(seconds)` | the zone's abbreviation at that instant (`str`), or `None` |

The default, `jqlite.SystemClock()`, reads `time.time()` and the zone of the process (`time.localtime`), so daylight saving time follows the date; an instant the C library cannot represent takes the offset of now. It gives no abbreviation, so `%Z` prints the offset (`+02`, or `+0530` when the minutes are not zero). `%Z` of a UTC time (`strftime`, `todate`) prints `UTC`.

A fixed clock makes date programs reproducible:

```python
import jqlite

class FixedClock:
    def now(self):
        return 1425599507.0

    def offset(self, seconds):
        return -3 * 3600

    def abbreviation(self, seconds):
        return None

options = jqlite.Options(clock=FixedClock())
program = 'now, (now | strflocaltime("%Y-%m-%dT%H:%M:%S %z %Z"))'
print(jqlite.parse(program, options).evaluate(None))
# [1425599507, '2015-03-05T20:51:47 -0300 -03']
```

`clock=None` is accepted at run time, although the type annotation does not list it. It is the "no clock" host of the spec: `now` is the error `now/0 requires a host clock`, and the local zone is UTC (`strflocaltime` prints `%z` as `+0000` and `%Z` as `+00`).

## The depth limit

`max_depth` is the largest number of calls of jq-defined functions active at the same time, the program's own functions and those of the prelude (`map`, `select`, `walk`...) alike ([spec §11](../language/spec.md#11-limits)). There are no tail calls: a recursive call counts while it is active. A call beyond the limit is the run-time error `Maximum call depth exceeded`. It is an ordinary error: `try` catches it, and uncaught it raises `jqlite.JqError`.

```python
import jqlite

count = "def f: if . == 0 then 0 else (. - 1 | f) + 1 end; f"
expression = jqlite.parse(count, jqlite.Options(max_depth=10))
print(expression.evaluate(9))  # [9]
try:
    expression.evaluate(10)
except jqlite.JqError as e:
    print(e)  # Maximum call depth exceeded
```

- `max_depth` must be an `int` from 0 to 100,000; anything else (a `bool`, a `float`, a negative number) raises `ValueError` when the `Options` is created.
- With `max_depth=0`, every call of a jq-defined function fails, `map` included; native builtins and operators still run.
- Up to the limit, the program never fails because the Python stack is short: the library raises Python's recursion limit while it runs ([Evaluating](evaluate.md#threads)).

## Debug and stderr handlers

`debug` receives the input of each `debug`, and each message of `debug(msgs)`. `stderr` receives the input of each `stderr`. They receive the value as a Python JSON value, as is: no `["DEBUG:", ...]` wrapper and no text. Without a handler the value is dropped. In every case `debug` and `stderr` output their input unchanged.

```python
import jqlite

logged = []
options = jqlite.Options(debug=logged.append, stderr=logged.append)
print(jqlite.parse('debug, debug("m", {a: .}), stderr', options).evaluate(1))  # [1, 1, 1]
print(logged)  # [1, 'm', {'a': 1}, 1]
```

The handlers run on the thread of the evaluation, in the order of the program. An exception raised by a handler propagates out of `evaluate` and ends the evaluation.
