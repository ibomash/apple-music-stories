---
id: TASK-20
title: Define MDX subset specification for iOS renderer
status: Done
assignee: []
created_date: '2026-01-17 17:00'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a design doc (doc-6) that explicitly defines the MDX subset supported by the iOS story renderer:

- Standard Markdown elements supported
- Custom components: `<Section>` and `<MediaRef>` with their attribute schemas
- Explicitly unsupported features: JSX expressions, imports, arbitrary components
- Examples of valid and invalid syntax
- Error handling for unsupported syntax

Related: doc-5 - iOS-story-renderer-architecture
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Documented MDX subset in doc-6 with supported Markdown, component schemas, unsupported syntax, examples, and diagnostic behavior.
<!-- SECTION:NOTES:END -->
