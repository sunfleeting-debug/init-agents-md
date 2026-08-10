# Docstring Conventions

When the skill auto-fills missing docstrings on public API, it follows these
language-specific conventions.

## TypeScript (JSDoc)

```typescript
/**
 * Short description.
 *
 * Longer description if needed.
 *
 * @param paramName - description
 * @returns description
 * @throws description (if applicable)
 */
export function fnName(paramName: Type): ReturnType {
    ...
}
```

## Python (Google-style)

```python
def fn_name(param_name: Type) -> ReturnType:
    """Short description.

    Longer description if needed.

    Args:
        param_name: Description.

    Returns:
        Description.

    Raises:
        ExceptionType: Description.
    """
    ...
```

## Java (Javadoc)

```java
/**
 * Short description.
 *
 * <p>Longer description if needed.
 *
 * @param paramName description
 * @return description
 * @throws ExceptionType description
 */
public ReturnType fnName(Type paramName) {
    ...
}
```

## What the skill does NOT do

- Touch internal/private symbols.
- Modify function bodies or signatures.
- Add docstrings to test files (those are typically not part of public API).
- Generate docstrings with fabricated behavior descriptions — if the
  function's behavior is unclear from the name/signature alone, the skill
  asks the user instead of guessing.
