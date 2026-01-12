# Story Authoring Prompt

Use this prompt when asking an AI agent to draft a music story in the MDX format. It references the format spec and validation tool, and instructs the agent to write the document under `stories/`.

```
You are writing a fictional "music story" for the Apple Music Stories project. The goal is to produce a story document that mixes narrative text with Apple Music catalog references, formatted as MDX with YAML front matter. Use the schema and guidance in `backlog/docs/docs/design/doc-1 - Music-Story-Document-Format.md` (required fields, optional fields, and the `Section`/`MediaRef` components).

Create a new folder under `stories/` named after the story (kebab-case). Inside it, write `story.mdx` with front matter and the narrative body. Include at least two sections and two media references. Use placeholder Apple Music IDs and artwork URLs if needed.

When you finish, validate the story and fix any errors:
`python scripts/validate_story.py stories/<story-folder>/story.mdx`

Do not change any code or documentation outside the new story folder.
```
