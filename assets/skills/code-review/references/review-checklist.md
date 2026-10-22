# Code Review Checklist

Use this as a lookup while working through a changed file. Not every item applies to every diff.

## General

- [ ] The change matches the stated intent (commit message, issue, or request).
- [ ] Names describe what the code does, not how it does it.
- [ ] No leftover debug code, commented-out blocks, or `console.log` in a shipped path.
- [ ] No duplicated logic that already exists in the codebase.
- [ ] Public API changes are reflected in docs and in every call site.
- [ ] Feature flags or config gates behave correctly when the flag is absent.
- [ ] Backward compatibility is preserved, or the break is intentional and announced.

## Correctness

- [ ] Conditionals are not inverted; the negative branch does what it should.
- [ ] Off-by-one at every boundary: index, slice, range, loop, pagination.
- [ ] Null, undefined, and empty-collection cases are handled where they can occur.
- [ ] `await` is present on every promise-returning call that the result depends on.
- [ ] Promise rejections are handled (`catch`, `try/catch`, or explicit `.catch`).
- [ ] Errors are not swallowed into a silent success.
- [ ] Resource cleanup happens on every path, including early returns and throws.
- [ ] Timeouts and retries are set where a network call can hang.
- [ ] Concurrency: shared mutable state is not read and written without synchronization.
- [ ] Floating-point money or rounding-sensitive math uses the right type.
- [ ] Integer overflow or truncation is handled where sizes are large.

## Security

- [ ] No secret, token, or password committed in source, config, fixtures, or logs.
- [ ] Input from the user, network, or file is validated before use.
- [ ] Shell commands use argument arrays, not string interpolation.
- [ ] SQL uses parameterized queries; no string-built SQL.
- [ ] File paths are canonicalized and confirmed to stay inside the intended root.
- [ ] URLs from user input are restricted to an allowlist of hosts and schemes.
- [ ] Every new endpoint or handler has an authentication and authorization check.
- [ ] Authorization is checked on the object, not only on the route.
- [ ] Deserialization of untrusted input uses a safe format.
- [ ] Rate limiting or size limits exist on expensive or public operations.
- [ ] Error responses to clients do not leak stack traces or internal paths.
- [ ] Redirect targets are validated to prevent open redirect.
- [ ] Dependencies were checked for known vulnerabilities.

## Data and migrations

- [ ] A schema change has a migration and a rollback path.
- [ ] The migration is safe to run while the previous version is still serving traffic.
- [ ] Writes are idempotent, or a duplicate write is harmless.
- [ ] Multi-step writes are wrapped in a transaction, or are designed to be resumable.
- [ ] Destructive changes (`DROP`, `TRUNCATE`, bulk `DELETE`) preserve the data the app needs.
- [ ] Defaults and nullability in the schema match how the code reads the column.
- [ ] Indexes support the new query pattern.
- [ ] Large tables are not locked during migration.

## Testing

- [ ] New behavior has a test that fails without the change.
- [ ] The test asserts on behavior, not on implementation details.
- [ ] Edge cases are covered: empty, one, many, boundary, invalid input.
- [ ] Failure paths are covered, not just the happy path.
- [ ] No test was deleted or weakened to make the change pass.
- [ ] Tests are deterministic: no real clock, no network, no ordering assumptions.
- [ ] Test names state the behavior, not the function name.

## Frontend and browser

- [ ] Loading, empty, and error states all exist.
- [ ] The layout holds at narrow and wide widths.
- [ ] Accessibility: labels, keyboard path, focus order, contrast.
- [ ] Effect dependencies are complete; stale closures are gone.
- [ ] User input is not re-rendered from state without sanitization.
- [ ] Long lists are virtualized or paginated.
- [ ] Images and fonts have size constraints.

## Node, TypeScript, and JavaScript

- [ ] `await` inside loops is intentional; sequential awaits in a hot path are justified.
- [ ] Unhandled promise rejections are not possible.
- [ ] `for...of` vs `for` over an array that is mutated during iteration.
- [ ] Prototype-polluting keys are stripped when merging user objects.
- [ ] `parseInt` without a radix, or a radix that is wrong.
- [ ] Numeric strings compared with `==` instead of `===`.
- [ ] `null` vs `undefined` semantics respected in optional chaining.
- [ ] Type assertions (`as`) do not hide a real type error.

## Python

- [ ] Mutable default arguments in function signatures.
- [ ] Broad `except:` or `except Exception` that swallows a real error.
- [ ] Resource files opened without a context manager.
- [ ] Missing `await` on a coroutine call, or a coroutine never awaited.
- [ ] Imports inside a hot function.
- [ ] String formatting that does not escape user input for shell or SQL.

## Go

- [ ] Errors wrapped with context instead of discarded.
- [ ] Deferred calls in the right order.
- [ ] Channels closed by the sender only, never by a receiver.
- [ ] `nil` map writes panic.
- [ ] Context cancellation respected in long-running loops.
- [ ] Goroutine leaks from unbuffered channels or missing `WaitGroup` usage.

## Java and Kotlin

- [ ] Resources closed in `try-with-resources`.
- [ ] Nullability honored; optionals not dereferenced blindly.
- [ ] Concurrency primitives used instead of `synchronized` on shared state.
- [ ] Exceptions not swallowed in a `catch` block that only logs.
- [ ] Android: lifecycle-aware coroutine scopes, no leaked `Activity` references.

## Severity guide

| Severity | Meaning |
| --- | --- |
| Critical | Data loss, security hole, or crash on a normal path. |
| High | Wrong behavior on a realistic path, missing authorization, broken contract. |
| Medium | Edge case, error-handling gap, or missing test on non-trivial logic. |
| Low | Readability, naming, dead code, small duplication. |
