---
title: "API reference"
---

# API reference

The public API of the crate `jqlite` is what the crate root re-exports. The modules `binding`, `builtins`, `runtime`, `stack_guard`, `syntax` and `values` are also public, so that the crate's tests and benchmark runner can drive the engine, but they are hidden from the documentation and are not a stable interface. Paths below are from the crate root: `jqlite::parse`, `jqlite::JqValue`.

## Functions

| Signature | Description |
| --- | --- |
| `pub fn parse(expression: &str) -> Result<JqExpression, JqError>` | Parses and binds a program with the default options; the error is `JqError::Parse`. An empty program is `.`. |
| `pub fn parse_with(expression: &str, options: &JqOptions) -> Result<JqExpression, JqError>` | Parses and binds a program, loading its modules through `options.resolver`; the options apply to every evaluation. |
| `pub fn evaluate(expression: &str, input: JqValue) -> Result<Vec<JqValue>, JqError>` | Parses with the default options and evaluates once, returning all the outputs. |

## The parsed expression

`pub struct JqExpression`: `Clone` (cheap, the program is shared), `Send`, `Sync`.

| Signature | Description |
| --- | --- |
| `pub fn evaluate(&self, input: JqValue) -> Result<Vec<JqValue>, JqError>` | Evaluates on `input` and returns all the outputs; on an error, no outputs. |
| `pub fn evaluate_with(&self, input: JqValue, variables: &HashMap<String, JqValue>) -> Result<Vec<JqValue>, JqError>` | The same, with host variables by name without `$`; a bad name is `JqError::Variable`. |
| `pub fn for_each(&self, input: JqValue, variables: Option<&HashMap<String, JqValue>>, on_result: impl FnMut(JqValue) -> bool) -> Result<(), JqError>` | Gives each output to `on_result` as it is produced; `false` stops (not an error); an error is returned after the outputs before it. |

## Options

`pub struct JqOptions`: `Clone`, `Default`, `Send`, `Sync`. All fields are public.

| Field | Description |
| --- | --- |
| `pub resolver: Option<Arc<dyn JqResolver>>` | Resolves `import`, `include` and `modulemeta`. Default `None`: no module exists. |
| `pub environment: Option<Vec<(String, String)>>` | The variables of `$ENV` and `env`, in order. Default `None`: the process environment. |
| `pub clock: Arc<dyn JqClock>` | The source of `now` and of the local zone. Default `Arc::new(SystemClock)`. |
| `pub max_depth: usize` | The most calls of jq-defined functions active at once. Default `1000`. |
| `pub debug: Option<JqHandler>` | Receives the values of `debug` and `debug(msgs)`. Default `None`: dropped. |
| `pub stderr: Option<JqHandler>` | Receives the values of `stderr`. Default `None`: dropped. |

`JqHandler` is `Arc<dyn Fn(&JqValue) + Send + Sync>`. The alias itself is not exported: write the type out, or pass `Some(Arc::new(|value: &JqValue| ...))`.

| Item | Description |
| --- | --- |
| `pub trait JqClock: Send + Sync` | The source of `now` and of the local zone; called from any evaluating thread. |
| `fn now(&self) -> f64` | The current time in seconds since the Unix epoch. |
| `fn offset(&self, seconds: f64) -> i32` | The offset of the local zone from UTC at that instant, in seconds east of UTC. |
| `fn abbreviation(&self, _seconds: f64) -> Option<String>` | The zone's abbreviation at that instant, for `%Z`. Provided: `None` (then `%Z` prints the offset). |
| `pub struct SystemClock;` | The system time, with UTC as the local zone. `Clone`, `Copy`, `Debug`, `Default`. |
| `pub struct FixedOffsetClock { pub offset_seconds: i32 }` | The system time, with a zone at a fixed offset (seconds east of UTC) and no abbreviation. `Clone`, `Copy`, `Debug`. |

## Resolvers

| Item | Description |
| --- | --- |
| `pub trait JqResolver: Send + Sync` | Finds the modules of `import`, `include` and `modulemeta`. |
| `fn canonical_path(&self, path: &str, kind: JqModuleKind, metadata: Option<&JqValue>, from_path: Option<&str>) -> Option<String>` | The identity of the module `path`, imported with `metadata` from the module `from_path` (`None`: the main program); `None` if there is none. |
| `fn read(&self, canonical_path: &str) -> std::io::Result<String>` | The text of the module; an `Err` becomes a parse error with its text. |
| `pub enum JqModuleKind { Code, Data }` | A module of definitions, or a data module (`import "p" as $name;`). `Clone`, `Copy`, `Debug`, `PartialEq`, `Eq`. |
| `pub struct JqFileResolver` | A resolver over files; implements `JqResolver`. `Clone`, `Debug`. |
| `pub fn new(base_directory: impl AsRef<Path>) -> JqFileResolver` | Paths of the main program are relative to `base_directory` (made absolute); paths in a module, to its directory. `.jq` or `.json` is added to a path without an extension. |
| `pub fn base_directory(&self) -> &Path` | The absolute base directory. |

## Errors

`pub enum JqError`: `Clone`, `Debug`, `Display` (the message), `std::error::Error`, `Send`, `Sync`.

| Item | Description |
| --- | --- |
| `Parse { message: String, line: u32, column: u32 }` | A syntax or binding error found by `parse`; 1-based line and column in code points, in the program or in the module the message names. |
| `Runtime { message: String, value: JqValue }` | An error that reached the top of the program; `value` is the error value, `message` the value if it is a string, else its JSON text and ` (not a string)`. |
| `Halt { message: String, value: JqValue, exit_code: i32 }` | `halt_error` ended the evaluation, with its input and exit code (5 by default). |
| `Variable { message: String }` | A host variable name that is not a jq identifier, or `ENV`. |
| `Json { message: String }` | A text given to `JqValue::parse` that is not one JSON value. |
| `pub fn message(&self) -> &str` | The message of any variant. |
| `pub fn value(&self) -> Option<&JqValue>` | The error value of `Runtime` and `Halt`; `None` for the others. |

## Values

`pub enum JqValue { Null, False, True, Number(f64), String(JqString), Array(JqArray), Object(JqObject) }`: `Clone` (cheap), `Default` (`Null`), `Display` and `Debug` (canonical JSON), `FromStr` (`JqValue::parse`), `Send`, `Sync`. No `PartialEq`.

| Signature | Description |
| --- | --- |
| `pub fn parse(text: &str) -> Result<JqValue, JqError>` | Reads exactly one JSON value (spec §5.3); the error is `JqError::Json`. |
| `pub fn to_json(&self) -> String` | The canonical compact JSON text (spec §5.1): NaN as `null`, infinities as ±1.7976931348623157e+308. |
| `pub fn from_bool(value: bool) -> JqValue` | `True` or `False`. |
| `pub fn from_number(value: f64) -> JqValue` | `Number(value)`. |
| `pub fn from_string(value: String) -> JqValue` | A string value that takes `value`. |
| `pub fn from_text(value: &str) -> JqValue` | A string value with a copy of `value`. |
| `pub fn from_array(value: JqArray) -> JqValue` | `Array(value)`. |
| `pub fn from_object(value: JqObject) -> JqValue` | `Object(value)`. |
| `pub fn kind(&self) -> JqKind` | The kind of the value. |
| `pub fn is_truthy(&self) -> bool` | `false` for `Null` and `False`, `true` otherwise. |
| `pub fn type_name(&self) -> &'static str` | The name jq's `type` gives: `"null"`, `"boolean"`, `"number"`, `"string"`, `"array"`, `"object"`. |
| `pub fn as_number(&self) -> f64` | The number; panics on another kind. |
| `pub fn as_string(&self) -> &str` | The text; panics on another kind. |
| `pub fn as_array(&self) -> &JqArray` | The array; panics on another kind. |
| `pub fn as_object(&self) -> &JqObject` | The object; panics on another kind. |

Conversions into `JqValue`: `From<bool>`, `From<f64>`, `From<i32>`, `From<&str>`, `From<String>`, `From<Vec<JqValue>>`, `From<JqArray>`, `From<JqObject>`, `From<Option<T>>` where `T: Into<JqValue>` (`None` is `Null`), and `FromIterator<(K, V)>` where `K: Into<String>, V: Into<JqValue>` (an object in that order; a repeated key keeps its first position and last value).

| Item | Description |
| --- | --- |
| `pub type JqString = Arc<String>` | The text of a string value or of an object key. |
| `pub enum JqKind { Null, False, True, Number, String, Array, Object }` | The kinds, declared in jq's sort order. `Clone`, `Copy`, `Debug`, `PartialEq`, `Eq`, `PartialOrd`, `Ord`, `Hash`. |

`pub struct JqArray`: `Clone` (cheap), `Default` (empty); `&JqArray` is `IntoIterator<Item = &JqValue>`.

| Signature | Description |
| --- | --- |
| `pub fn empty() -> JqArray` | The empty array. |
| `pub fn of(items: &[JqValue]) -> JqArray` | An array with a copy of `items`. |
| `pub fn from_owned(items: Vec<JqValue>) -> JqArray` | An array over `items`, without copying. |
| `pub fn count(&self) -> usize` | The number of elements. |
| `pub fn is_empty(&self) -> bool` | Whether there are no elements. |
| `pub fn get(&self, index: usize) -> &JqValue` | The element at `index`; panics past the end. |
| `pub fn as_slice(&self) -> &[JqValue]` | The elements. |
| `pub fn iter(&self) -> std::slice::Iter<'_, JqValue>` | An iterator over the elements. |
| `pub fn is_unique(&self) -> bool` | Whether this array is the only owner of its elements. |
| `pub fn make_mut(&mut self) -> &mut Vec<JqValue>` | The elements to change in place, copied first if shared. |
| `pub fn into_vec(self) -> Vec<JqValue>` | The elements: the array's own if not shared, else a copy. |
| `pub fn append(self, value: JqValue) -> JqArray` | The array with `value` added at the end. |
| `pub fn concat(self, other: JqArray) -> JqArray` | This array followed by `other`. |
| `pub fn slice(self, from: usize, to: usize) -> JqArray` | The elements `from..to`; panics unless `from <= to <= count`. |
| `pub fn set_item(self, index: usize, value: JqValue) -> JqArray` | The array with `value` at `index`, padded with nulls past the end. |

`pub struct JqObject`: `Clone` (cheap), `Default` (empty). Keys keep their insertion order.

| Signature | Description |
| --- | --- |
| `pub fn empty() -> JqObject` | The empty object. |
| `pub fn with_capacity(capacity: usize) -> JqObject` | An empty object with room for `capacity` entries. |
| `pub fn from_owned(entries: Vec<(JqString, JqValue)>) -> JqObject` | An object over `entries`, whose keys must be distinct (not checked). |
| `pub fn from_entries(entries: Vec<(JqString, JqValue)>) -> JqObject` | An object from entries in order, where a repeated key keeps its first position and last value. |
| `pub fn count(&self) -> usize` | The number of entries. |
| `pub fn is_empty(&self) -> bool` | Whether there are no entries. |
| `pub fn key_at(&self, index: usize) -> &JqString` | The key at `index` in insertion order. |
| `pub fn value_at(&self, index: usize) -> &JqValue` | The value at `index` in insertion order. |
| `pub fn entries(&self) -> &[(JqString, JqValue)]` | The entries in insertion order. |
| `pub fn contains_key(&self, key: &str) -> bool` | Whether `key` is present. |
| `pub fn get(&self, key: &str) -> Option<&JqValue>` | The value of `key`. |
| `pub fn index_of(&self, key: &str) -> Option<usize>` | The position of `key` in insertion order. |
| `pub fn is_unique(&self) -> bool` | Whether this object is the only owner of its entries. |
| `pub fn set(self, key: JqString, value: JqValue) -> JqObject` | The object with `key` set: an existing key keeps its position, a new one goes last. |
| `pub fn insert(&mut self, key: JqString, value: JqValue)` | Sets `key` in place, copying the entries first if shared. |
| `pub fn slot(&mut self, key: &JqString) -> &mut JqValue` | The value of `key` to change in place; a missing key is added with `null`. |
| `pub fn remove(self, key: &str) -> JqObject` | The object without `key`; the other keys keep their order. |
| `pub fn merge(self, other: JqObject) -> JqObject` | jq's `+` on objects: the values of `other` win, its new keys go last. |
| `pub fn sorted_order(&self) -> &[u32]` | The positions of the entries in code point order of their keys (jq's `keys`). |
| `pub fn into_entries(self) -> Vec<(JqString, JqValue)>` | The entries: the object's own if not shared, else a copy. |
