# Project Guidance

## GDScript Style

- Prefer explicit variable types with `=` when the type is known, for example `var damage: int = 40`, instead of type inference with `:=`.

## Collaborative Code Changes

- For non-trivial changes, do not edit project files automatically. First show the proposed code, explain why it is structured that way and how it fits into the wider system, then wait for the user's explicit approval before applying it.
- The user will review and usually add approved code manually to understand every change and maintain ownership of the architecture.
- Directly edit project files only when the user explicitly asks to do so, typically for a small or straightforward change.
