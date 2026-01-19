---
id: task-38
title: Configure Apple Docs MCP server
status: Done
assignee: []
created_date: '2026-01-19 22:17'
updated_date: '2026-01-19 22:18'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up repo-level OpenCode MCP config for apple-doc-mcp-server and verify via opencode CLI.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review OpenCode MCP server config requirements and expected file location\n- Add repo-level MCP server configuration for apple-doc-mcp-server (npx apple-doc-mcp-server@latest)\n- Verify configuration via opencode CLI if possible
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Created repo-level opencode.jsonc with apple_docs local MCP (npx -y apple-doc-mcp-server@latest). Verified via ┌  MCP Servers
│
●  ✓ apple_docs [90mconnected
│      [90mnpx -y apple-doc-mcp-server@latest
│
└  1 server(s).
<!-- SECTION:NOTES:END -->
