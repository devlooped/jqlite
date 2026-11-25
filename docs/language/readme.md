---
title: "The language"
---

# The language

jqlite is a profile of [jq 1.8](https://jqlang.org/manual/v1.8/): the jq language as a library, defined so that a program gives the same outputs in every implementation. This section holds for all of them. How you call the engine from your language (values in and out, options, modules, errors) is in the section of each [implementation](#implementations).

## Where to read

| Page | What it is |
| --- | --- |
| [A tour](tour.md) | The language in a quarter of an hour, on one small document: paths, pipes, construction, functions, updates, errors. |
| [jq 1.8 manual](manual.md) | The manual of jq itself. What it says about the language holds in jqlite, except the differences below. |
| [Specification](spec.md) | The normative text. It defines the grammar, the values, the semantics, every builtin, the errors and the limits, and it is what every implementation is written from. |

## What is in the profile

The profile has the jq language: paths, pipes, generators, array and object construction, string interpolation, variables and destructuring (including `?//`), `def`, `reduce`, `foreach`, `label` and `break`, `try`/`catch` and `?`, path expressions and every assignment operator, and modules.

Its builtins ([§9 of the specification](spec.md#9-builtins)) cover types and selection, objects, arrays and collections, paths, strings, formats (`@base64`, `@uri`, `@csv`, `@tsv`, `@html`, `@json`, `@text`, `@sh`), dates, math and regular expressions.

Every builtin of jq 1.8 is in, except five:

- `get_search_list`, `get_jq_origin` and `get_prog_origin` describe the jq command line.
- `input` and `inputs` read the next input. An evaluation has one input value; an API that takes several values, such as a stream of JSON Lines, evaluates each one alone.

## Differences from jq

A jq program that does not depend on one of the differences behaves as in jq 1.8. Each difference is there to make the result exact and equal in every language. The ones you are most likely to meet:

| Area | In jqlite |
| --- | --- |
| Numbers | IEEE doubles, written in one canonical form: `1.0` is `1`, and `1e-7`, `1e+21`, `-0` are written so. NaN is written as `null` and the infinities as ±`1.7976931348623157e+308`. |
| Regular expressions | One flavor, common to the engines of every language, in place of Oniguruma's: no lookaround, backreferences or inline flags; `\d`, `\w`, `\s` and `\b` are ASCII; the `i` flag folds ASCII letters only. |
| Variables | A `$name` that the program does not bind is a host variable, given by the caller of an evaluation. Without a value it is the run-time error `$name is not defined`, not a compile error. |
| Recursion | The depth of calls is limited (1000 by default, an option of the host), and there are no tail calls. Past the limit the error is `Maximum call depth exceeded`, which `try` catches. |
| Dates | Their own calendar and English names, with no locale and no C library. |
| `debug`, `stderr` | Their values go to handlers of the host, not to a process stream. |
| `break` | `try` does not catch it. |

The complete list, with what jq does in each case and why jqlite differs, is [§13 of the specification](spec.md#13-differences-from-jq-18). The limits are in [§11](spec.md#11-limits).

## What an implementation gives its host

The specification also fixes what every implementation offers to the program that calls it ([§12](spec.md#12-host-interface)), so the same topics exist in every language:

| Topic | What it is |
| --- | --- |
| Evaluating | A program is parsed and bound once, and can then be evaluated many times, from several threads at once. The outputs come all together or one by one, and the host can stop the stream. |
| Values | The input and the outputs, in the host's JSON values or in the engine's. |
| Variables | Host variables, `$name`, given for each evaluation. |
| Options | The environment of `$ENV`, the clock and the local zone, the depth limit, the handlers of `debug` and `stderr`. |
| Modules | A resolver that the host supplies for `import`, `include` and `modulemeta`. |
| Errors | A syntax or binding error with its line and column, an uncaught error with its value, and `halt_error` with its exit code. |
| JSON Lines | One evaluation for each value of a stream. |

## Implementations

<div class="jqlite-cards">
  {{~ for language in site.jqlite_languages ~}}
  <a class="jqlite-card" href="{{site.basepath}}/{{language.id}}/">
    <span class="jqlite-card-title"><span class="jqlite-language-tag" aria-hidden="true">{{language.tag}}</span>{{language.name}}</span>
    <span class="jqlite-card-package">{{language.package}}</span>
  </a>
  {{~ end ~}}
</div>
