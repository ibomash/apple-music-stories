---
id: TASK-91
title: Install Puppeteer MCP and test story server
status: Done
assignee: []
created_date: '2026-01-24 17:14'
updated_date: '2026-01-24 17:17'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Install Puppeteer + puppeteer-mcp-server and run a basic Puppeteer-driven check against the HTML story server.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review repo setup for Node/Puppeteer usage
- Add puppeteer + puppeteer-mcp-server dependencies and config
- Run HTML story server and drive a Puppeteer test
- Capture results + update task notes
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Initialized npm (package.json) and installed puppeteer + puppeteer-mcp-server.
- Added scripts/puppeteer_story_test.js to open the story index, follow first story link, and report counts.
- Ran story server: uv run scripts/render_story.py serve --host 127.0.0.1 --port 8000
- Puppeteer run output:
  - Index title: Apple Music Stories
  - Story URL: http://127.0.0.1:8000/stories/sample-night-drive
  - Story title: After Midnight on Coastal FM
  - Sections: 2
  - Media cards: 2
- npx mcp-server-puppeteer --help produced no output (command returned immediately).
<!-- SECTION:NOTES:END -->
