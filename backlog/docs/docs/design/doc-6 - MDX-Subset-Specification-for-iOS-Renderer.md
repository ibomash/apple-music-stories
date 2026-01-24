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
- A `<Section>` may contain paragraphs plus the supported custom blocks below.
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

### `<DropQuote>`
Pull quote for emphasis.

**Syntax**
```mdx
<DropQuote attribution="Prince">Purple rain, purple rain.</DropQuote>
```

**Attributes**
- `attribution` (optional): short attribution or speaker.

**Content rules**
- `<DropQuote>` contains plain Markdown text only.

### `<SideNote>`
Margin-style callout note.

**Syntax**
```mdx
<SideNote label="Context">
  The 1984 tour redefined arena staging.
</SideNote>
```

**Attributes**
- `label` (optional): short label for the note.

**Content rules**
- `<SideNote>` contains plain Markdown text only.

### `<FeatureBox>`
Expandable or emphasized feature module.

**Syntax**
```mdx
<FeatureBox title="The Purple Years" summary="A quick recap" expandable="true">
  The Minneapolis sessions blurred funk, pop, and rock.
</FeatureBox>
```

**Attributes**
- `title` (optional): headline for the box.
- `summary` (optional): short summary shown in collapsed state.
- `expandable` (optional): `true` or `false`, defaults to `false`.

**Content rules**
- `<FeatureBox>` contains plain Markdown text only.

### `<FactGrid>`
Grid of label/value facts.

**Syntax**
```mdx
<FactGrid>
  <Fact label="Albums" value="15" />
  <Fact label="Grammys" value="7" />
</FactGrid>
```

**Attributes**
- None.

**Content rules**
- `<FactGrid>` can only contain `<Fact />` children.

### `<Fact />`
Single fact item for a `FactGrid`.

**Attributes**
- `label` (required): short fact label.
- `value` (required): value text.

### `<Timeline>`
Ordered timeline of dated entries.

**Syntax**
```mdx
<Timeline>
  <TimelineItem year="1982">1999 lands and changes the skyline.</TimelineItem>
  <TimelineItem year="1984">Purple Rain takes over radio.</TimelineItem>
</Timeline>
```

**Attributes**
- None.

**Content rules**
- `<Timeline>` can only contain `<TimelineItem>` children.

### `<TimelineItem>`
Timeline entry with a year label and text.

**Attributes**
- `year` (required): year label.

**Content rules**
- `<TimelineItem>` contains plain Markdown text only.

### `<Gallery>`
Image gallery with captions.

**Syntax**
```mdx
<Gallery>
  <GalleryImage src="assets/purple-1.jpg" alt="Prince live" caption="Purple Rain tour" />
  <GalleryImage src="assets/purple-2.jpg" alt="Studio" caption="Paisley Park" />
</Gallery>
```

**Attributes**
- None.

**Content rules**
- `<Gallery>` can only contain `<GalleryImage />` children.

### `<GalleryImage />`
Image entry for a gallery.

**Attributes**
- `src` (required): asset path.
- `alt` (required): alt text.
- `caption` (optional): caption text.
- `credit` (optional): credit text.

### `<FullBleed />`
Edge-to-edge media block.

**Syntax**
```mdx
<FullBleed src="assets/prince-stage.jpg" alt="Prince on stage" caption="Purple Rain finale" />
```

**Attributes**
- `src` (required): asset path.
- `alt` (required): alt text.
- `caption` (optional): caption text.
- `credit` (optional): credit text.
- `kind` (optional): `image` or `video`. Defaults to `image`.

**Content rules**
- `<FullBleed />` must be self-closing and appear on its own line.

## Explicitly Unsupported MDX
The following syntax is rejected by the iOS parser:
- `import`/`export` statements.
- JSX expressions or JavaScript in attributes (`{}` or `{...spread}`).
- Custom components other than the list in this document.
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
