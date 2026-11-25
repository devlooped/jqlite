---
title: "API reference"
---

# API reference

The exported identifiers of package `jqlite` (module `github.com/devlooped/jqlite/go`), from the
files `jqlite.go`, `options.go`, `resolver.go`, `errors.go`, `value.go` and `lines.go`. `Value`,
`Kind`, `Array` and `Object` are aliases of the engine's types in `internal/values`; their methods
are listed here too.

## Functions

| Signature | Description |
| --- | --- |
| `func Parse(expression string) (*Expression, error)` | Parses and binds with the default options; the error is a `*ParseError`. The empty string is `.`. |
| `func ParseWithResolver(expression string, resolver Resolver) (*Expression, error)` | `ParseWithOptions` with only `Resolver` set. |
| `func ParseWithOptions(expression string, options Options) (*Expression, error)` | Parses and binds, loading modules through `options.Resolver`; the options apply to every evaluation. |
| `func MustParse(expression string) *Expression` | `Parse` that panics on an error. |
| `func Evaluate(expression string, input Value, variables map[string]Value) ([]Value, error)` | Parses with the default options and evaluates on `input`, returning all results. |
| `func EvaluateLines(expression string, r io.Reader, variables map[string]Value) iter.Seq2[Value, error]` | Parses with the default options and evaluates on each value of a JSON Lines stream; a parse error is the only element. |

## The parsed expression

| Signature | Description |
| --- | --- |
| `type Expression struct` | A parsed and bound program; immutable, safe to evaluate from many goroutines at once. No exported fields. |
| `func (e *Expression) Evaluate(input Value, variables map[string]Value) ([]Value, error)` | All results; on an error, `nil` results and a `*Error`, `*HaltError` or `*VariableError`. |
| `func (e *Expression) EvaluateFunc(input Value, variables map[string]Value, onResult func(Value) bool) error` | Gives each result to `onResult` as it is produced; `onResult` returns `false` to stop (not an error). |
| `func (e *Expression) Results(input Value, variables map[string]Value) iter.Seq2[Value, error]` | The results for `range`, each with a `nil` error, then `Null` with an error if one ends the evaluation; `break` stops it. |
| `func (e *Expression) Lines(r io.Reader, variables map[string]Value) iter.Seq2[Value, error]` | Evaluates each value of a JSON Lines stream alone; blank lines are skipped; the first error ends the sequence. |

## Options

| Signature | Description |
| --- | --- |
| `type Options struct` | What an expression takes from its host; the zero value is the defaults. |
| `Resolver Resolver` | Resolves `import`, `include` and `modulemeta`; `nil`: no module exists. |
| `Environment []string` | `$ENV` as `NAME=value` entries in order; `nil`: the process environment; empty non-nil: `{}`. |
| `Now func() time.Time` | The source of `now`; `nil`: `time.Now`. |
| `Location *time.Location` | The local zone of `localtime`, `strflocaltime`, `%z`, `%Z`; `nil`: `time.Local`. |
| `MaxDepth int` | Maximum depth of jq-defined function calls; 0 (or less): 1000. Past it: `Maximum call depth exceeded`. |
| `Debug func(Value)` | Receives the values of `debug` and `debug(msg)`; `nil`: dropped. |
| `Stderr func(Value)` | Receives the values of `stderr`; `nil`: dropped. |

## Resolvers

| Signature | Description |
| --- | --- |
| `type ModuleKind int` | The kind of module an import asks for. |
| `const ModuleCode ModuleKind` | A code module (`.jq`): `import "p" as name;`, `include "p";`. |
| `const ModuleData ModuleKind` | A data module (`.json`): `import "p" as $name;`. |
| `type Resolver interface` | Finds modules; must be safe for concurrent use (`modulemeta` calls it during evaluations). |
| `CanonicalPath(path string, kind ModuleKind, metadata *Value, fromPath string) (string, error)` | Method of `Resolver`: the module's identity, or `""` when there is none; `fromPath` is `""` for the main program. |
| `Open(canonicalPath string) (io.ReadCloser, error)` | Method of `Resolver`: reads the module at a canonical path. |
| `type FileResolver struct` | A `Resolver` over the file system; paths relative to the importing module or `BaseDirectory`; `.jq` or `.json` added when there is no extension. |
| `BaseDirectory string` | Field of `FileResolver`: the directory of the main program's imports. |
| `func NewFileResolver(baseDirectory string) *FileResolver` | A `FileResolver` with `baseDirectory` made absolute. |
| `func (r *FileResolver) CanonicalPath(p string, kind ModuleKind, _ *Value, fromPath string) (string, error)` | The absolute path of an existing file, or `""`. |
| `func (r *FileResolver) Open(canonicalPath string) (io.ReadCloser, error)` | `os.Open`. |
| `type FSResolver struct` | A `Resolver` over an `fs.FS` (such as an `embed.FS`); same path rules as `FileResolver`. |
| `FS fs.FS` | Field of `FSResolver`: the file system. |
| `Root string` | Field of `FSResolver`: the directory of the main program's imports, inside `FS`. |
| `func (r *FSResolver) CanonicalPath(p string, kind ModuleKind, _ *Value, fromPath string) (string, error)` | The path inside `FS` of an existing file, or `""`. |
| `func (r *FSResolver) Open(canonicalPath string) (io.ReadCloser, error)` | `FS.Open`. |

## Errors

| Signature | Description |
| --- | --- |
| `type ParseError struct` | A syntax or binding error, returned by the parse functions. |
| `Message string`, `Line int`, `Column int`, `Module string` | Fields of `ParseError`: the text with its place, 1-based position (columns in code points), the module's canonical path or `""`. |
| `func (e *ParseError) Error() string` | Returns `Message`. |
| `type Error struct` | An error that reached the top of the program. |
| `Message string`, `Value Value` | Fields of `Error`: the value if it is a string, else its JSON text and ` (not a string)`; the error value. |
| `func (e *Error) Error() string` | Returns `Message`. |
| `type HaltError struct` | `halt_error` ending an evaluation (`halt` is not an error). |
| `Message string`, `Value Value`, `ExitCode int` | Fields of `HaltError`: as for `Error`; the input of `halt_error`; its exit code (5 by default). |
| `func (e *HaltError) Error() string` | Returns `Message`. |
| `type VariableError struct` | A host variable name that is not a jq identifier, or `ENV`. |
| `Name string` | Field of `VariableError`: the rejected key. |
| `func (e *VariableError) Error() string` | Explains why the name is rejected. |

## Values

| Signature | Description |
| --- | --- |
| `type Value = values.Value` | An immutable jqlite value; the zero value is `null`. |
| `type Kind = values.Kind` | The kind of a value, declared in jq's sort order. |
| `type Array = values.Array` | The array of an array value (used as `*Array`). |
| `type Object = values.Object` | The object of an object value, keys in insertion order (used as `*Object`). |
| `const KindNull`, `KindFalse`, `KindTrue`, `KindNumber`, `KindString`, `KindArray`, `KindObject` | The kinds. |
| `var Null`, `False`, `True Value` | The three constant values. |
| `type Member struct` | A key and its value, for `NewObject`; fields `Key string`, `Value Value`. |
| `func Bool(b bool) Value` | `True` or `False`. |
| `func Number(n float64) Value` | A number. |
| `func String(s string) Value` | A string; ill-formed UTF-8 becomes U+FFFD. |
| `func NewArray(items ...Value) Value` | An array of the items (copied). |
| `func NewObject(members ...Member) Value` | An object in the members' order; a repeated key keeps its first position and its last value. |
| `func ParseJSON(text string) (Value, error)` | Reads exactly one JSON value (NaN and Infinity accepted); the error has jq's message. |
| `func ToJSON(v Value) string` | Compact canonical JSON text; NaN as `null`, infinities as `±1.7976931348623157e+308`. |
| `func FromAny(v any) (Value, error)` | Converts nil, bools, numbers, strings, `json.Number`, slices, string-keyed maps (keys sorted), pointers. |
| `func ToAny(v Value) any` | Converts to `nil`, `bool`, `float64`, `string`, `[]any`, `map[string]any`; key order is lost. |
| `func (v Value) Kind() Kind` | The kind. |
| `func (v Value) IsTruthy() bool` | `false` for `null` and `false`, `true` otherwise. |
| `func (v Value) TypeName() string` | The name jq's `type` gives: `"null"`, `"boolean"`, `"number"`, ... |
| `func (v Value) AsNumber() float64` | The number; panics if the value is not a number. |
| `func (v Value) AsString() string` | The string; panics if the value is not a string. |
| `func (v Value) AsArray() *Array` | The array; panics if the value is not an array. |
| `func (v Value) AsObject() *Object` | The object; panics if the value is not an object. |
| `func (v Value) String() string` | The canonical JSON text, as `ToJSON`. |
| `func (k Kind) String() string` | `"Null"`, `"False"`, `"True"`, `"Number"`, `"String"`, `"Array"` or `"Object"`. |
| `func (a *Array) Count() int` | The number of elements. |
| `func (a *Array) At(index int) Value` | The element at `index`, `0 <= index < Count()`. |
| `func (a *Array) ToArray() []Value` | A new slice of the elements. |
| `func (a *Array) CopyTo(target []Value, targetIndex int)` | Copies the elements into `target` from `targetIndex`. |
| `func (a *Array) Append(value Value) *Array` | A new array with `value` added at the end. |
| `func (a *Array) Concat(other *Array) *Array` | A new array: this one followed by `other`. |
| `func (a *Array) Slice(from, to int) *Array` | The elements from `from` to `to` (excluded), `0 <= from <= to <= Count()`. |
| `func (a *Array) SetItem(index int, value Value) *Array` | A copy with `value` at `index`; past the end pads with `null`; a negative index panics. |
| `func (o *Object) Count() int` | The number of keys. |
| `func (o *Object) KeyAt(index int) string` | The key at `index`, in insertion order. |
| `func (o *Object) ValueAt(index int) Value` | The value at `index`, in insertion order. |
| `func (o *Object) TryGetValue(key string) (Value, bool)` | The value of `key`, if present. |
| `func (o *Object) ContainsKey(key string) bool` | Whether `key` is present. |
| `func (o *Object) IndexOf(key string) int` | The position of `key` in insertion order, or -1. |
| `func (o *Object) SortedKeys() []string` | The keys in code point order, as jq's `keys`. |
| `func (o *Object) Set(key string, value Value) *Object` | A copy with `key` set: an existing key keeps its position, a new one goes last. |
| `func (o *Object) Remove(key string) *Object` | A copy without `key`. |
| `func (o *Object) Merge(other *Object) *Object` | jq's `+` on objects: the keys of `other` win. |

> [!NOTE]
> No exported function makes a `Value` of an `*Array` or `*Object`, so the results of `Append`,
> `Set` and the other copying methods cannot be passed back to an evaluation. Build inputs with
> `NewArray`, `NewObject`, `ParseJSON` or `FromAny`.
