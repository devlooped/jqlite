---
title: "jqlite for Python"
---

# jqlite for Python

`jqlite` for Python is a port of the jqlite engine to Python. It is a file-by-file port of the .NET reference engine. It implements the same [specification](../language/spec.md) and passes the same conformance corpus. You give it a jq program and Python JSON values (what `json.loads` returns), and it returns Python JSON values.

## Requirements

- Python 3.11 or later (`requires-python = ">=3.11"`).
- No dependencies: the package uses the standard library only.
- The package imports as `jqlite` and ships type information (`py.typed`).

## Getting it

The manifest, [`python/pyproject.toml`](https://github.com/devlooped/jqlite/blob/main/python/pyproject.toml), declares the package `jqlite`, version `1.0.0`. The repository does not publish it to PyPI. Install it from a clone of the repository:

```shell-session
$ git clone https://github.com/devlooped/jqlite.git
$ python -m pip install ./jqlite/python
```

The package has nothing to build. You can also skip the install and put the `python` folder of the clone on `sys.path` (or `PYTHONPATH`), which is how the tests of the port run.

## A first example

```python
import jqlite

orders = {
    "customer": "Ada",
    "items": [
        {"name": "pen", "price": 1.5, "qty": 4},
        {"name": "ink", "price": 12, "qty": 1},
    ],
}

program = "{customer, total: (.items | map(.price * .qty) | add)}"
for result in jqlite.evaluate(program, orders):
    print(result)
```

```text
{'customer': 'Ada', 'total': 18}
```

`jqlite.evaluate` parses the program, runs it on one input value and returns the list of all its outputs. A program can give zero, one or many outputs:

```python
import jqlite

print(jqlite.evaluate(".[] | select(. > 1)", [1, 2, 3]))  # [2, 3]
print(jqlite.evaluate("empty", None))                     # []
```

To run one program on many values, parse it once with `jqlite.parse` and call `evaluate` on the result: see [Evaluating](evaluate.md).

## In this section

| Page | What it covers |
| --- | --- |
| [Evaluating](evaluate.md) | `evaluate`, `parse`, streaming results, threads |
| [Values](values.md) | how Python values go in and come out |
| [Variables](variables.md) | passing `$name` variables from Python |
| [Options](options.md) | environment, clock, depth limit, `debug` and `stderr` |
| [Modules](modules.md) | `import`, `include`, resolvers |
| [Errors](errors.md) | the exceptions, `halt`, `try` |
| [JSON Lines](jsonl.md) | one evaluation per value of a stream |
| [API reference](api.md) | every public name of the package |

The language itself is described in [the language guide](../language/readme.md). How this port is built, tested and laid out, and where it differs from the .NET reference, is in [the port's README](port.md).
