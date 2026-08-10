# Public API Scanning

The skill needs to know what counts as "public" in each language so it can
measure docstring coverage and (optionally) fill in missing docstrings.

## TypeScript / JavaScript (Node)

Public = exported symbol. Scan:

- `^export (async )?function NAME`
- `^export class NAME`
- `^export const NAME`
- `^export let NAME`
- `^export var NAME`
- `^export interface NAME`
- `^export type NAME`

Skip files under `node_modules`, `dist`, `build`, `.next`.

## Python

Public = top-level `def NAME` or `class NAME` at column 0, where NAME does
not start with `_`. Scan `.py` files; skip `.venv`, `__pycache__`.

## Java

Public = `public class NAME`, `public interface NAME`, or method declarations
starting with `public`. Scan `.java` files under `src/main/java`.

## Docstring detection

- TypeScript: a `/** ... */` block on the line(s) immediately preceding.
- Python: a `"""..."""` block on the line(s) immediately preceding.
- Java: a `/** ... */` block on the line(s) immediately preceding.

Coverage = (publicSymbols - undocumented) / publicSymbols.

## Threshold

Below 80% coverage, the gap-analyzer emits a `docstring-coverage` gap item.
