---
id: doc-6
title: MDX Subset Specification for iOS Renderer
type: design
created_date: '2026-01-17 17:00'
---

## Summary
Define the exact MDX subset accepted by the iOS renderer so the Swift parser can remain deterministic, small, and aligned with the story schema in `doc-1 - Music-Story-Document-Format` and the parser expectations in `doc-5 - iOS story renderer architecture`.

## Document Shape
- A story file is `story.mdx` with YAML front matter followed by the MDX body.
- Front matter must satisfy the schema in `doc-1` (`schema_version`, `id`, `title`, `authors`, `publish_date`, `sections`, `media`).
- The MDX body is a **sequence of `<Section>` blocks only**. No text is allowed outside a `<Section>`.
- Attributes must be plain double-quoted strings (no `{}` expressions, no spreads, no single quotes).

## Supported Markdown
The iOS renderer supports a narrative-first subset of Markdown inside each `<Section>`:

### Block-level
- Paragraphs separated by blank lines.
- Soft line breaks inside a paragraph (treated as spaces).
- Hard line breaks using two trailing spaces.

### Inline
- Emphasis (`*italic*` or `_italic_`).
- Strong emphasis (`**bold**` or `__bold__`).
- Inline code (`` `code` ``).
- Links (`[label](https://example.com)`; URLs must be absolute).

Everything else is treated as unsupported (see below).

## Custom Components
### `<Section>`
Defines the boundaries and metadata for a story section.

**Syntax**
```mdx
<Section id="intro" title="Opening" layout="lede">
  Narrative text...
</Section>
```

**Attributes**
- `id` (required): Section identifier, must match a `sections[].id` entry in front matter.
- `title` (required): Section title, must match `sections[].title` in front matter.
- `layout` (optional): `lede` or `body`. Defaults to `body`.

**Content rules**
- A `<Section>` may contain paragraphs and `<MediaRef />` blocks only.
- `<Section>` blocks cannot be nested.

### `<MediaRef />`
Embeds a media reference defined in the front matter.

**Syntax**
```mdx
<MediaRef ref="trk-echo" intent="preview" />
```

**Attributes**
- `ref` (required): Must match a `media[].key` entry in front matter.
- `intent` (optional): One of `preview`, `full`, or `autoplay`.
  - `preview`: show a preview-first play action (default).
  - `full`: play full item on tap.
  - `autoplay`: begin full playback immediately when the section loads.

**Content rules**
- `<MediaRef />` must be self-closing and appear on its own line.
- `<MediaRef />` cannot contain children.

## Explicitly Unsupported MDX
The following syntax is rejected by the iOS parser:
- `import`/`export` statements.
- JSX expressions or JavaScript in attributes (`{}` or `{...spread}`).
- Custom components other than `<Section>` and `<MediaRef />`.
- Raw HTML blocks.
- Markdown headings, lists, blockquotes, tables, images, or fenced code blocks.

## Examples
### Valid
```mdx
<Section id="intro" title="Signal Check" layout="lede">
The signal flickers into focus, and the night swells with *soft* static.

<MediaRef ref="trk-echo" intent="autoplay" />
</Section>
```

### Invalid
```mdx
import Player from "./Player"
```
```mdx
<Section id="intro">
# Heading inside section
</Section>
```
```mdx
<MediaRef ref={trackId} />
```
```mdx
Text outside any section.
```

## Error Handling & Diagnostics
The parser emits `ValidationDiagnostic` values (per `doc-5`):

**Errors (render blocked)**
- Missing/invalid YAML front matter delimiters or parsing failure.
- Text outside of a `<Section>` block.
- `<Section>` missing required `id`/`title` attributes.
- `<Section>` tags not properly closed.
- `<MediaRef />` missing `ref` or using non-string attributes.
- Unsupported MDX/JSX constructs (imports, expressions, unknown components).

**Warnings (render continues with fallback)**
- `<MediaRef />` references a `ref` not present in `media[]` (render a placeholder card).
- `intent` not in the allowed set (fall back to `preview`).
- `layout` not in `lede`/`body` (fall back to `body`).
- Unsupported Markdown inside a section (render raw text without formatting).
