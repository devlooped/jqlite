---
title: "API reference"
---

# API reference

The public API is the package `com.devlooped.jqlite`. Values are the types of
`com.devlooped.jqlite.values`, listed at the end. The other packages (`syntax`, `binding`,
`runtime`, `builtins`) are the engine: their types are public for the engine's own use and are not
part of the host API.

## Entry points

`public final class Jq`: static methods only.

| Member | Description |
| --- | --- |
| `static JqExpression parse(String expression)` | Parses and binds with `JqOptions.defaults()`. Throws `JqParseException`. |
| `static JqExpression parse(String expression, JqOptions options)` | Parses and binds with the options; modules are read now through the options' resolver. |
| `static JqExpression parse(String expression, JqResolver resolver)` | The default options with `resolver`. |
| `static List<JqValue> evaluate(String expression, JqValue input)` | Parses with the default options and returns all the results. |
| `static List<JqValue> evaluate(String expression, JqValue input, Map<String, JqValue> variables)` | The same, with host variables. |
| `static void evaluateLines(JqExpression expression, Reader jsonLines, Map<String, JqValue> variables, Predicate<JqValue> onResult) throws IOException` | Evaluates the expression on each JSON value of a JSON Lines reader, alone; `onResult` returns `false` to stop. |

`public final class JqJson`: JSON text in and out.

| Member | Description |
| --- | --- |
| `static JqValue parse(String json)` | Reads exactly one JSON value; invalid text throws `JqException`. |
| `static String toJson(JqValue value)` | The compact canonical JSON text of a value; NaN as `null`, infinities as `±1.7976931348623157e+308`. |

## The parsed expression

`public final class JqExpression`: immutable, safe to evaluate from many threads at once. Created
by `Jq.parse` only.

| Member | Description |
| --- | --- |
| `List<JqValue> evaluate(JqValue input)` | All the results, computed before the list is returned. |
| `List<JqValue> evaluate(JqValue input, Map<String, JqValue> variables)` | The same, with host variables (`null` for none). |
| `void evaluate(JqValue input, Predicate<JqValue> onResult)` | Gives each result to `onResult` as it is produced; `false` stops the evaluation. |
| `void evaluate(JqValue input, Map<String, JqValue> variables, Predicate<JqValue> onResult)` | The same, with host variables. |

Every `evaluate` throws `IllegalArgumentException` for an invalid variable name or a `null` variable
value, `NullPointerException` for a `null` input or callback, `JqException` for an uncaught error
and `JqHaltException` for `halt_error`.

## Options

`public final class JqOptions`: immutable; each `with` method returns a copy.

| Member | Description |
| --- | --- |
| `static final int MAX_DEPTH_LIMIT` | `100_000`, the largest accepted `maxDepth`. |
| `static JqOptions defaults()` | No resolver, the process environment, `Clock.systemDefaultZone()`, a depth of 1000, no handlers. |
| `JqResolver resolver()` | The module resolver, or `null`: no module exists. |
| `JqOptions withResolver(JqResolver value)` | Sets the resolver; `null` removes it. |
| `Map<String, String> environment()` | The variables of `$ENV` and `env`, or `null`: the process environment. |
| `JqOptions withEnvironment(Map<String, String> value)` | Sets an unmodifiable copy, in the map's iteration order; `null` restores the process environment. |
| `Clock clock()` | The source of `now` and of the local time zone. |
| `JqOptions withClock(Clock value)` | Sets the clock; `null` throws `NullPointerException`. |
| `int maxDepth()` | The largest number of jqlite function calls active at once. |
| `JqOptions withMaxDepth(int value)` | Sets it; outside 1 to `MAX_DEPTH_LIMIT` throws `IllegalArgumentException`. |
| `Consumer<JqValue> debug()` | The handler of `debug` and `debug(msg)`, or `null`. |
| `JqOptions withDebug(Consumer<JqValue> value)` | Sets it; `null` drops the values. |
| `Consumer<JqValue> stderr()` | The handler of `stderr`, or `null`. |
| `JqOptions withStderr(Consumer<JqValue> value)` | Sets it; `null` drops the values. |

## Resolvers

`public abstract class JqResolver`: finds and opens modules.

| Member | Description |
| --- | --- |
| `abstract String getCanonicalPath(String path, JqModuleKind kind, JqValue metadata, String fromPath) throws IOException` | The identity of the module, or `null` when it does not exist; `fromPath` is `null` for the main program. |
| `abstract Reader open(String canonicalPath) throws IOException` | The text of the module. |

`public enum JqModuleKind`

| Member | Description |
| --- | --- |
| `CODE` | A module of jq definitions (`import "p" as name;`, `include "p";`). |
| `DATA` | A sequence of JSON values (`import "p" as $name;`). |

`public class JqFileResolver extends JqResolver`

| Member | Description |
| --- | --- |
| `JqFileResolver(Path baseDirectory)` | Paths of the main program are relative to `baseDirectory`, made absolute and normalized. |
| `Path baseDirectory()` | That directory. |
| `String getCanonicalPath(String path, JqModuleKind kind, JqValue metadata, String fromPath)` | The full file path, relative to the importing module's directory; adds `.jq` or `.json` to a name without an extension; `null` if no such file. |
| `Reader open(String canonicalPath) throws IOException` | Reads the file as UTF-8. |

`public class JqResourceResolver extends JqResolver`

| Member | Description |
| --- | --- |
| `JqResourceResolver(ClassLoader loader, String prefix)` | Resources of `loader` under a slash-separated `prefix` (may be empty); `null` arguments throw `NullPointerException`. |
| `String prefix()` | The prefix. |
| `String getCanonicalPath(String path, JqModuleKind kind, JqValue metadata, String fromPath)` | The resource name: the prefix or the importing module's directory, `/`, the path, plus `.jq` or `.json` unless already there; `null` if no such resource. |
| `Reader open(String canonicalPath) throws IOException` | Reads the resource as UTF-8. |

## Exceptions

All unchecked.

| Type | Member | Description |
| --- | --- | --- |
| `public class JqException extends RuntimeException` | `JqException(String message)` | An exception without an error value. |
| | `JqException(String message, JqValue value)` | An exception for a jqlite error value. |
| | `JqValue value()` | The error value of an uncaught run-time error, or `null`. |
| `public final class JqParseException extends JqException` | `int line()` | The 1-based line, in the program or in the module the message names. |
| | `int column()` | The 1-based column, in code points. |
| `public final class JqHaltException extends JqException` | `int exitCode()` | The exit code given to `halt_error` (5 without an argument). |

## Values

`public sealed interface JqValue`, in `com.devlooped.jqlite.values`: an immutable value.

| Member | Description |
| --- | --- |
| `JqValue NULL`, `FALSE`, `TRUE` | The constants. |
| `static JqValue fromBool(boolean value)` | `TRUE` or `FALSE`. |
| `static JqValue fromNumber(double value)` | A number; NaN and infinities allowed. |
| `static JqValue fromString(String value)` | A string; a lone surrogate becomes U+FFFD. |
| `static JqValue fromArray(JqArray value)`, `fromObject(JqObject value)` | The value itself. |
| `static JqValue concat(JqValue left, JqValue right)` | jq's `+` on two strings. |
| `JqKind kind()` | The kind of the value. |
| `boolean isTruthy()` | `false` for null and false, `true` otherwise. |
| `String typeName()` | jq's `type`: `"null"`, `"boolean"`, `"number"`, `"string"`, `"array"`, `"object"`. |
| `double asNumber()`, `String asString()`, `JqArray asArray()`, `JqObject asObject()` | The content; the wrong kind throws `IllegalStateException`. |

`public enum JqKind`: `NULL`, `FALSE`, `TRUE`, `NUMBER`, `STRING`, `ARRAY`, `OBJECT`, in jq's sort
order.

`public final class JqArray implements JqValue`

| Member | Description |
| --- | --- |
| `static final JqArray EMPTY` | `[]`. |
| `static JqArray of(JqValue... items)` | An array with a copy of the items. |
| `static JqArray fromOwned(JqValue[] items)`, `fromOwned(JqValue[] items, int count)` | An array over the items without a copy: never write them again. |
| `int count()`, `JqValue get(int index)` | Length and element; a bad index throws `IndexOutOfBoundsException`. |
| `JqArray append(JqValue value)`, `concat(JqArray other)` | A new array with more elements. |
| `JqArray slice(int from, int to)`, `setItem(int index, JqValue value)` | A part; a copy with one element set (padding with nulls). |
| `JqValue[] toArray()`, `void copyTo(JqValue[] target, int targetIndex)` | The elements as a Java array. |

`public final class JqObject implements JqValue`

| Member | Description |
| --- | --- |
| `static final JqObject EMPTY` | The empty object `{}`. |
| `int count()`, `String keyAt(int index)`, `JqValue valueAt(int index)` | Entries by position, in insertion order. |
| `JqValue get(String key)`, `boolean containsKey(String key)`, `int indexOf(String key)` | Lookup; `get` returns `null` and `indexOf` -1 for an absent key. |
| `JqObject set(String key, JqValue value)`, `remove(String key)`, `merge(JqObject other)` | A copy with a key set, removed, or the keys of `other` added (jq's `+`). |
| `String[] sortedKeys()` | The keys in code point order; shared, do not write it. |

`public final class JqObjectBuilder`: a mutable object under construction.

| Member | Description |
| --- | --- |
| `JqObjectBuilder()`, `JqObjectBuilder(int capacity)` | An empty builder. |
| `JqObjectBuilder(JqObject source)`, `JqObjectBuilder(JqObject source, int extra)` | A builder starting from the entries of `source`. |
| `void set(String key, JqValue value)` | Sets a key: an existing key keeps its position, a new key goes last. |
| `JqValue get(String key)`, `boolean remove(String key)`, `int count()` | Lookup, removal, size. |
| `JqObject toObject()` | The object; the builder must not be used afterwards. |

`JqArrayBuilder` (`JqArrayBuilder(JqArray source)`, `count()`, `get(int)`, `set(int, JqValue)`,
`toArray()`) is the array counterpart. `JqString` is the class of long strings built by `+`; read it
through `kind()` and `asString()` as any string.
