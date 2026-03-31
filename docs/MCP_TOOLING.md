# MCP_TOOLING.md

This document defines optional Codex-specific tooling heuristics for this starter.
Projects that do not use Codex/MCP as a standard workflow may remove this document.
It is not a complete MCP manual.

## Scope

This document owns:

- Codex-specific tool-selection heuristics
- optional MCP usage defaults for projects that keep Codex in the workflow
- narrow guidance for the tools covered below

This document does not own:

- general engineering behavior
- TDD workflow
- repo routing

## Keep This Doc When

Keep this document only if the project uses Codex/MCP as a normal part of delivery or review work.
If the project does not rely on Codex/MCP, remove this file during bootstrap.

## sequential-thinking

Use sequential-thinking MCP to structure reasoning before implementation when complexity exceeds a single-step solution.

Use sequential-thinking MCP when:
- The task involves multiple steps.
- There is ambiguity in requirements.
- Tradeoffs must be evaluated.
- Refactoring or architectural decisions are involved.
- Success criteria are not immediately obvious.
- The change affects more than one file or system boundary.

Skip sequential-thinking when:
- The task is trivial (e.g., typo fixes, renaming, small literal change).
- The solution path is obvious and single-step.
- No tradeoffs or design decisions are involved.

## Context7

Always use **Context7 MCP** whenever working with:

- Apple frameworks
- External libraries
- Build configuration
- Dependency setup
- API usage
- Platform capabilities (iOS availability, permissions, entitlements)
