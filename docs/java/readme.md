---
title: "jqlite for Java"
---

# jqlite for Java

jqlite for Java is the Java port of jqlite, the portable profile of the [jq language](../language/readme.md).
It carries the .NET reference engine over file by file, follows the same [spec](../language/spec.md)
and passes the same conformance corpus. It has no run-time dependency.

## Requirements

- Java 21 or later (the POM compiles with `release` 21).
- No run-time dependency. JUnit 5 is used by the tests only.
- Maven, through the wrapper of the repository (`java/mvnw`, `java/mvnw.cmd`), to build it. The
  wrapper downloads Maven 3.9 on first use and needs `JAVA_HOME` or `java` on the `PATH`.

## Getting it

The POM declares these coordinates:

| Group | Artifact | Version |
| --- | --- | --- |
| `com.devlooped` | `jqlite` | `1.0.0` |

The package is not published to Maven Central or another registry. Build it from the repository:

```shell-session
$ git clone https://github.com/devlooped/jqlite.git
$ cd jqlite/java
$ ./mvnw package
```

On Windows run `.\mvnw.cmd package`. The build compiles, runs the tests and writes the library to
`target/jqlite.jar`. The prelude inside the jar is
[`spec/prelude.jq`](https://github.com/devlooped/jqlite/blob/main/spec/prelude.jq), copied
unchanged. Put the jar on your class path, or run `./mvnw install` to place the artifact in your
local Maven repository and depend on it from another project:

```xml
<dependency>
  <groupId>com.devlooped</groupId>
  <artifactId>jqlite</artifactId>
  <version>1.0.0</version>
</dependency>
```

The public API is in the package `com.devlooped.jqlite`. Values are the engine's immutable
`JqValue` types, in `com.devlooped.jqlite.values`.

## A first example

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqJson;
import com.devlooped.jqlite.values.JqValue;
import java.util.List;

public class First {
    public static void main(String[] args) {
        JqValue input = JqJson.parse("""
            {"orders": [
              {"id": 1, "total": 25.5, "status": "paid"},
              {"id": 2, "total": 10, "status": "open"},
              {"id": 3, "total": 99.99, "status": "paid"}
            ]}
            """);

        List<JqValue> results = Jq.evaluate(".orders[] | select(.status == \"paid\") | .id", input);
        for (JqValue result : results) {
            System.out.println(JqJson.toJson(result));
        }
    }
}
```

It prints:

```text
1
3
```

`JqJson.parse` reads JSON text into a `JqValue`. `Jq.evaluate` parses the program, runs it on the
input and returns every result. `JqJson.toJson` writes a result as compact JSON text. To run a
program many times, parse it once with `Jq.parse`: see [Evaluating](evaluate.md).

## In this section

| Page | What it covers |
| --- | --- |
| [Evaluating](evaluate.md) | one-shot evaluation, parse once and evaluate many times, streaming, threads |
| [Values](values.md) | `JqValue` in and out: numbers, strings, arrays, objects, key order |
| [Variables](variables.md) | host variables (`$name`), `$ENV`, `$__loc__` |
| [Options](options.md) | `JqOptions`: environment, clock, depth limit, `debug` and `stderr` |
| [Modules](modules.md) | `import`, `include`, data modules, `modulemeta`, resolvers |
| [Errors](errors.md) | `JqParseException`, `JqException`, `JqHaltException`, `try` |
| [JSON Lines](jsonl.md) | evaluating a program on each value of a stream |
| [API reference](api.md) | every public type and member |
| [Port notes](port.md) | build, tests, layout and differences from the reference |
