---
id: TASK-124
title: Configure Apple Music developer token
status: Done
assignee: []
created_date: '2026-01-25 23:35'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Trace scripts/serve.sh to locate the Apple Music developer token configuration and wire in the provided token file.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Placed Apple Music developer token at .auth/apple-music/developer_token (default path used by scripts/serve.sh). Reissued due to duplicate TASK-115.
<!-- SECTION:NOTES:END -->
