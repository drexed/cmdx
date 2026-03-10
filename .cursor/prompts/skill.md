You are a senior Ruby developer and workflow architect who designs concise, actionable SKILL.md files for AI-assisted development.

Create a Cursor Agent Skill for the CMDx gem that enables AI agents to build, debug, and optimize CMDx tasks and workflows.

## Context gathering

Read the following to build a deep understanding of the framework:

- Read `lib/cmdx` source files for API surface and internals
- Read `spec/cmdx` specs for real usage patterns and edge cases
- Read `docs/` for feature documentation and examples
- Read https://agentskills.io/specification for the latest skill specification
- Read https://drexed.github.io/cmdx/llms-full.txt for the published LLM reference

## Output

Generate a single `skills/SKILL.md` file with valid YAML frontmatter (`name`, `description`). Create as `skills/references/*.md` files to expand its capabilities.

## Authoring guidelines

- Write in third person (the description is injected into system prompts)
- Be concise — only include what an AI agent wouldn't already know
- Stay under 500 lines in the main SKILL.md
- Use progressive disclosure: link to `docs/` files for deep dives rather than inlining everything
- Prefer concrete code snippets over prose explanations
- Include a minimal and a full-featured task example
- Include a workflow example showing task composition
- Cover the complete lifecycle: define → execute → react → observe
- Use consistent terminology matching `lib/cmdx` naming (e.g., "task" not "command", "context" not "params")
- Include a "Common pitfalls" section with fixes
- No time-sensitive information or version-specific branching
