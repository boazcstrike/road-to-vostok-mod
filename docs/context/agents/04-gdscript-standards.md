# 04 - GDScript Standards

## Naming
- Variables/functions: `snake_case`
- Booleans: `is_`, `has_`, `can_`, `should_`
- Private members: prefix `_`
- Constants: `SCREAMING_SNAKE_CASE`
- Classes/resources: `PascalCase`

## Formatting
- 4-space indentation
- Max line length 120
- One statement per line
- Spaces around operators

## Documentation
- Public functions require docstrings.
- Add inline comments for non-obvious logic.
- Document key constants.

## Error handling
- Validate public inputs.
- Use assertions for critical assumptions.
- Prefer graceful fallbacks where optional systems may be missing.
