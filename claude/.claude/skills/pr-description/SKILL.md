---
name: pr-description
description: Write a PR description in Lauren's voice and open a pull request
version: 1.0.0
---

# PR Description Skill

Writes a pull request description in Lauren's voice, then opens the PR.

If a `LOCAL.md` file exists next to this file, read it first. It holds employer-specific conventions (ticket systems, title format, risk rubric, link formats) and wins wherever it conflicts with this file.

## Usage

```
/pr-description [title]
```

`title` is optional. If omitted, derive it from the branch name and diff.

## Step 1: Gather context

Run in parallel:
- `git diff <base>...HEAD` to see what changed (use the repo's default branch as `<base>`)
- `git log <base>...HEAD --oneline` to read the commit messages
- `git branch --show-current` to get the branch name

If the branch name contains a ticket identifier (letters, dash, digits), look it up with whichever tracker tool is available and read its title and description.

## Step 2: Understand the change

Work out what changed, why it changed, how risky it is, and how to verify it.

## Step 3: Write the description

**Prose**
- First person, conversational, direct. Lead with why the change is needed, then what it does.
- Write paragraphs, not bullet lists, in the prose section.
- Be brief for simple changes ("Comment-only change.") and thorough for complex ones.
- Say so plainly for backports and no-ops.
- Note caveats, limitations and follow-up work.
- Link related context inline with descriptive link text.
- Same-repo PRs may use a bare `#123`. Cross-repo PRs must use a full markdown link that names the repo, such as `[other-repo #123](https://github.com/owner/other-repo/pull/123)`. A bare number autolinks to the current repo and points at the wrong PR.

**Sections**
If the repo has a pull request template, fill in its headings. Otherwise add a short "Risk" section describing the worst-case failure, and a "Testing" section with concrete steps to verify the change.

**Do not include**
- A `## Summary` header with bullets
- A "Generated with Claude Code" footer
- Boilerplate such as "This PR..."
- A title in the body

## Step 4: Choose the title

Use the user's title verbatim if given. Otherwise follow the convention visible in recent `git log` output, in imperative mood and under 90 characters.

## Step 5: Preview and confirm

Show the proposed title and body, then ask:

```
Open PR with this description? (yes/no)
```

Wait for an explicit "yes".

## Step 6: Open the PR

```bash
gh pr create --title "<title>" --body "<body>"
```

Return the PR URL.
