---
title: "Modules"
---

# Modules

A program can load jq definitions and JSON data from modules with `import` and `include`, and read a module's metadata with `modulemeta` ([spec §9.11](../language/spec.md#911-modules-optional-group)). The engine does not read files by itself: the host supplies modules through a resolver, set as `Options.resolver`. Without a resolver, no module exists.

## The directives

| Directive | Effect |
| --- | --- |
| `import "lib/util" as u;` | the definitions of a code module, called as `u::name` |
| `include "lib/util";` | the definitions of a code module, called by their own names |
| `import "config" as $cfg;` | the JSON values of a data module, as an array bound to `$cfg` and `$cfg::cfg` |
| `"lib/util" \| modulemeta` | the module's metadata object, with its `deps` and `defs` |

A directive may end with a metadata object, which is passed to the resolver: `import "a" as a {search: "./lib"};`.

## Using the file resolver

`jqlite.FileResolver(base_directory)` reads modules from the file system:

```python
import tempfile
from pathlib import Path
import jqlite

with tempfile.TemporaryDirectory() as folder:
    (Path(folder) / "lib").mkdir()
    (Path(folder) / "lib" / "text.jq").write_text(
        'module {"version": "1.0"};\ndef shout: ascii_upcase + "!";\n', encoding="utf-8")
    (Path(folder) / "colors.json").write_text(
        '{"red": "#f00"}\n{"green": "#0f0"}\n', encoding="utf-8")

    options = jqlite.Options(resolver=jqlite.FileResolver(folder))
    program = 'import "lib/text" as t; import "colors" as $c; (.name | t::shout), $c[1].green'
    print(jqlite.parse(program, options).evaluate({"name": "hi"}))  # ['HI!', '#0f0']
    print(jqlite.evaluate('"lib/text" | modulemeta', None, options=options))
    # [{'version': '1.0', 'deps': [], 'defs': ['shout/0']}]
```

`FileResolver` resolves paths this way:

- a path in the main program is relative to `base_directory` (made absolute when the resolver is created);
- a path in a module is relative to the directory of that module;
- a path without an extension gets `.jq` for a code module and `.json` for a data module; a path with one keeps it (`include "ext.jq";`);
- the canonical path of a module is its full file path; a file that does not exist resolves to nothing;
- files are read as UTF-8, an invalid byte becoming U+FFFD.

The package has no resolver for package resources. To ship modules inside a Python package, write a resolver over `importlib.resources` as below.

## Writing a resolver

Subclass `jqlite.Resolver` and implement its two methods:

```python
import jqlite

MODULES = {
    "mem:greet.jq": 'include "punctuation"; def greet: "hello " + . + mark;',
    "mem:punctuation.jq": 'def mark: "!";',
    "mem:names.json": '"ada" "grace"',
}

class MemoryResolver(jqlite.Resolver):
    def get_canonical_path(self, path, kind, metadata, from_path):
        suffix = ".jq" if kind == jqlite.ModuleKind.CODE else ".json"
        name = "mem:" + path + suffix
        return name if name in MODULES else None

    def read(self, canonical_path):
        return MODULES[canonical_path]

options = jqlite.Options(resolver=MemoryResolver())
program = 'include "greet"; import "names" as $n; $n[] | greet'
print(jqlite.parse(program, options).evaluate(None))  # ['hello ada!', 'hello grace!']
```

`get_canonical_path(path, kind, metadata, from_path)` maps a directive to the module's identity:

- `path` is the path as written in the directive;
- `kind` is `ModuleKind.CODE` (`import ... as name`, `include`, `modulemeta`) or `ModuleKind.DATA` (`import ... as $name`);
- `metadata` is the directive's metadata object as a `dict`, or `None`;
- `from_path` is the canonical path of the importing module, or `None` for the main program (and for `modulemeta`);
- it returns the canonical path, a non-empty `str`, or `None` when there is no such module.

`read(canonical_path)` returns the text of a module that `get_canonical_path` found. A data module's text is a sequence of JSON values separated by whitespace; no value binds `[]`.

The canonical path is the module's identity. Within one parse, a module is read and bound once per canonical path, however many directives name it. It also names the module in error messages and is the `file` of `$__loc__` inside the module.

## When resolution fails

At parse time, every failure is a `jqlite.JqParseError`:

| Cause | Message |
| --- | --- |
| `get_canonical_path` returns `None` or `""` | `module not found: <path>` |
| a module imports itself, directly or not | `circular import of <identity>` |
| `get_canonical_path` or `read` raises `JqError` or `OSError` | the text of that exception |
| a syntax or binding error inside a module | the error, with the module's identity, line and column |
| a data module that is not a sequence of JSON values | a message naming the module |

The line and column of the first three are those of the directive, in the program or the module that holds it. Any other exception raised by a resolver (`KeyError`, for example) is not converted: it propagates out of `parse` as it is.

```python
import jqlite

try:
    jqlite.parse('include "nonexistent"; .', jqlite.Options(resolver=jqlite.FileResolver(".")))
except jqlite.JqParseError as e:
    print(e)  # module not found: nonexistent at line 1, column 1
```

`modulemeta` calls the resolver while the program runs, and possibly from several threads at once if the expression is evaluated concurrently: a resolver must be safe to call that way. Its failures are run-time errors, which `try` catches:

```python
import jqlite

print(jqlite.evaluate('try ("nope" | modulemeta) catch .', None))  # ['module not found: nope']
```
