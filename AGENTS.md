## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used in this repository.

### Available skills
- rails-37signals-styleguide: Enforces 37signals/Basecamp/HEY Rails coding conventions when writing or reviewing Rails code. Use for Rails controllers, models, views, routes, migrations, Stimulus, CSS, jobs, tests, mailers, and architecture decisions. (file: /workspaces/styleguide/.claude/skills/rails-37signals-styleguide/SKILL.md)

### How to use skills
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task matches a skill description, you must use that skill for that turn.
- Mandatory trigger: For any task in this repo, always use `rails-37signals-styleguide`.
- Missing/blocked: If the skill path cannot be read, state that briefly and continue with the best fallback while preserving the intended style.
- Progressive disclosure: Open `SKILL.md` and read only what is needed; load specific reference files only when needed.
- Coordination: If multiple skills apply, use the minimal set and state order.
- Context hygiene: Summarize large sections and avoid loading unnecessary files.
