# Story Authoring Prompt

Use this prompt when asking an AI agent to draft a music story in the MDX format. It references the format spec and validation tool, and instructs the agent to write the document under `stories/`.

```
You are writing a fictional "music story" for the Apple Music Stories project. The goal is to produce a story document that mixes narrative text with Apple Music catalog references, formatted as MDX with YAML front matter. Use the schema and guidance in `backlog/docs/docs/design/doc-1 - Music-Story-Document-Format.md` (required fields, optional fields, and the MDX components).

Use typographic quotes and proper typography (smart quotes, apostrophes, en/em dashes, ellipses) within the story text; avoid straight quotes in narrative content.
Use the Apple Music skill to look up Apple Music catalog references (IDs, artwork, titles) rather than guessing them.
When adding album references, default to the original explicit, non-deluxe version unless the user specifies otherwise.

Image guidance (to avoid broken images on iOS):
- Prefer Apple Music artwork URLs from the Apple Music skill or iTunes lookup; avoid Wikimedia hotlinks (often 403).
- Use `.../100x100bb.jpg` for media `artwork_url` entries and `.../1200x1200bb.jpg` for hero/lead/gallery/full-bleed.
- If you must use external images, verify they allow hotlinking and return 200/204 to a HEAD request.
- Keep all image URLs HTTPS and direct to the image asset (no page URLs).

Create a new folder under `stories/` named after the story (kebab-case). Inside it, write `story.mdx` with front matter and the narrative body. Include at least two sections and two media references. Use placeholder Apple Music IDs and artwork URLs if needed.

Editorial guidance for magazine elements:
- Front matter: consider `accentColor`, `heroGradient`, `deck`, `typeRamp`, and `leadArt` to set the editorial tone; keep accents subtle.
- DropQuote: one or two per story, short and punchy, avoid full-paragraph quotes.
- SideNote: keep to a single short paragraph; do not stack multiple back to back.
- FeatureBox: use to summarize a key idea or context; prefer `expandable="true"` when it is longer than 3 sentences.
- FactGrid: 3-4 facts max; values should be short and scannable.
- Timeline: 3-6 entries; keep each entry to one sentence.
- Gallery: 2-4 images with captions; use artwork or scene-setting imagery.
- FullBleed: reserve for a single standout image; avoid using more than one.

When you finish, validate the story and fix any errors:
`python scripts/validate_story.py stories/<story-folder>/story.mdx`

Do not change any code or documentation outside the new story folder.
```
