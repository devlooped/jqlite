---
title: "API reference"
---

# API reference

The public names of the package are those of `jqlite.__all__`, all importable from `jqlite`. `Any` below stands for a Python JSON value ([Values](values.md)).

## Functions

| Signature | Description |
| --- | --- |
| `parse(expression: str, options: Options \| None = None) -> Expression` | Parses and binds `expression` (an empty one is `.`), loading its modules through `options.resolver`; raises `JqParseError`, or `TypeError` when `expression` is not a `str`. `None` is `Options()`. |
| `evaluate(expression: str, input: Any, variables: Mapping[str, Any] \| None = None, options: Options \| None = None) -> list[Any]` | `parse(expression, options).evaluate(input, variables)`. |
| `evaluate_each(expression: str \| Expression, inputs: Iterable[Any], variables: Mapping[str, Any] \| None = None) -> Iterator[Any]` | Generator: evaluates `expression` on each value of `inputs` in turn and yields the results; a `str` is parsed with the default options. |
| `evaluate_each_async(expression: str \| Expression, inputs: AsyncIterable[Any], variables: Mapping[str, Any] \| None = None) -> AsyncIterator[Any]` | `evaluate_each` over an asynchronous iterable; an asynchronous generator. |

## The parsed expression

`Expression` is returned by `parse`; it is not meant to be constructed directly. It is immutable and can be evaluated from many threads at once.

| Signature | Description |
| --- | --- |
| `Expression.evaluate(input: Any, variables: Mapping[str, Any] \| None = None) -> list[Any]` | Evaluates on `input` and returns all the results. Raises `ValueError` (variable name), `TypeError` (not a JSON value), `JqError`, `JqHaltError`. |
| `Expression.stream(input: Any, on_result: Callable[[Any], Any], variables: Mapping[str, Any] \| None = None) -> None` | Evaluates on `input`, calling `on_result` with each result as it is produced; `on_result` returning `False` stops the evaluation. Raises as `evaluate`, after the results produced before the error. |

## Options

`Options` is a frozen dataclass; every field is a keyword with a default. See [Options](options.md).

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `resolver` | `Resolver \| None` | `None` | Resolves `import`, `include` and `modulemeta`; `None`: no module exists. |
| `environment` | `Mapping[str, str] \| None` | `None` | The variables of `$ENV` and `env`; `None`: the process environment. |
| `clock` | `Clock` | `SystemClock()` | The source of `now` and of the local zone. |
| `max_depth` | `int` | `1000` | The most calls of jq-defined functions active at once, 0 to 100,000; `ValueError` otherwise. |
| `debug` | `Callable[[Any], None] \| None` | `None` | Receives each value of `debug` and each message of `debug(msgs)`. |
| `stderr` | `Callable[[Any], None] \| None` | `None` | Receives the input of each `stderr`. |

### Clock

`Clock` is a `typing.Protocol`: any object with these methods is a clock.

| Signature | Description |
| --- | --- |
| `Clock.now(self) -> float` | The current time, in seconds since the Unix epoch. |
| `Clock.offset(self, seconds: float) -> int` | The offset of the local zone from UTC at that instant, in seconds east of UTC. |
| `Clock.abbreviation(self, seconds: float) -> str \| None` | The abbreviation of the local zone at that instant, or `None` (`%Z` then prints the offset). |

`SystemClock()` implements `Clock` with `time.time()` and the zone of the process (`time.localtime`); its `abbreviation` always returns `None`.

## Resolvers

See [Modules](modules.md).

| Signature | Description |
| --- | --- |
| `ModuleKind.CODE`, `ModuleKind.DATA` | `enum.Enum` members: a code module (`.jq`) or a data module (JSON values). |
| `Resolver.get_canonical_path(self, path: str, kind: ModuleKind, metadata: dict[str, Any] \| None, from_path: str \| None) -> str \| None` | The canonical path of the module `path` imported from `from_path` (`None`: the main program), or `None` if there is none. The base class raises `NotImplementedError`. |
| `Resolver.read(self, canonical_path: str) -> str` | The text of the module at a canonical path. The base class raises `NotImplementedError`. |
| `FileResolver(base_directory: str)` | A `Resolver` over files: paths relative to the importing module, or to `base_directory` for the main program; adds `.jq` or `.json` to a path without extension. |
| `FileResolver.base_directory: str` | The absolute form of `base_directory`. |

## Errors

See [Errors](errors.md).

| Signature | Description |
| --- | --- |
| `JqError(message: str, value: Any = None)` | Subclass of `Exception`: an uncaught run-time error. `value` is the error value, `message` (also `str(e)`) its message. |
| `JqParseError(message: str, line: int, column: int, module: str \| None = None)` | Subclass of `JqError`: a syntax or binding error. `line` and `column` start at 1; `module` is the canonical path of the module, or `None`; `value` is `None`. |
| `JqHaltError(message: str, value: Any, exit_code: int)` | Subclass of `JqError`: `halt_error` ended the evaluation, with `value` and `exit_code`. |

## Values

The package has no value types of its own in its public API. Inputs, variables and results are `None`, `bool`, `int`, `float`, `str`, `list` and `dict`; `tuple` and any `Mapping` with `str` keys are also accepted as inputs. See [Values](values.md).
