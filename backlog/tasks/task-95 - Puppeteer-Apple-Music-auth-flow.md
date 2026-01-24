---
id: TASK-95
title: Puppeteer Apple Music auth flow
status: Done
assignee: []
created_date: '2026-01-24 21:40'
updated_date: '2026-01-24 21:40'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Plan manual Apple Music sign-in in Puppeteer and persist session for repo workflows, tests, and CI/CD.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review current repo auth/testing/CI patterns and where Puppeteer runs.
- Design interactive login workflow for local dev (manual sign-in + session export).
- Define persistence strategy (cookie/localStorage dump, storageState, or userDataDir) and storage location in repo workflow.
- Define secure handling for CI (encrypted artifacts/secrets, manual refresh cadence, fallback plan).
- Document testing steps and CI guardrails (skip when session missing, smoke checks).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Delivered workflow plan for manual Apple Music auth in Puppeteer, session persistence, and CI/CD handling.
<!-- SECTION:NOTES:END -->
