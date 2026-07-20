---
title: Getting started with sdlc
description: Install the sdlc plugin, onboard a repo, and drive your first Jira story to an open PR.
related-adrs: []
---

# Getting started with sdlc

In this tutorial we'll take a repo from nothing to its first automated pull request. We'll install
the sdlc plugin, onboard the repo with one command, pick a small Jira story, and run the pipeline on
it. By the end, sdlc will have written code, opened a PR, and left a comment on the story with a link
straight to it.

We'll follow one path the whole way through. Every step ends with something you can see, so you can
always confirm you're on track before moving on.

## Prerequisites

Before we start, make sure you have:

- **Claude Code** running in the repository you want to onboard.
- **A Jira Cloud project** you can create stories in, and its project key (for example `ACME`).
- **The `gh` CLI** (GitHub) and **the `acli` CLI** (Atlassian/Jira) installed. The plugin uses them
  for the PR and ticket integrations. On macOS: `brew install gh`, and
  `brew tap atlassian/homebrew-acli && brew install acli`.

You don't need to log in to `acli` yet. We'll do that together during onboarding.

## Step 1: Install the plugin

First we'll add the nightshift marketplace and install sdlc from it. In Claude Code, run:

```
/plugin marketplace add <path-or-git-url-to-the-nightshift-repo>
/plugin install sdlc@nightshift
```

You should see the marketplace register and the plugin install succeed. sdlc's companion plugins
(superpowers and claude-mem) are declared as dependencies, so they install alongside it without any
extra steps from you.

## Step 2: Onboard the repo with /sdlc:init

Now we'll teach the plugin about this repository. Run:

```
/sdlc:init
```

`/sdlc:init` is fully interactive and walks you through everything in order:

- It **checks that `gh` and `acli` are installed** and stops early with an install hint if either is
  missing.
- It **verifies your Jira login**, and if you're not authenticated yet, it collects your site, email,
  and an API token, then logs you in with `acli`.
- It **scans your repository** to detect the language, framework, package manager, and test and
  typecheck commands, using those as the pre-filled defaults for the questions it asks.
- It **asks a short series of questions** (one at a time) to confirm the project name, Jira project
  key, base branch, and which agents own code in this repo.

Answer each prompt as it comes. When it finishes, you should see a confirmation that it wrote your
config files, including `.claude/project/project-context.md`, and a short checklist of Jira fields to
set up by hand.

One field on that checklist matters for the next steps: the **Story point estimate** field must be
available on your project's stories. We'll use it in Step 3.

## Step 3: Create one small Jira story

Next we'll give the pipeline something small to work on. In your Jira project, create a single story:

- Give it a **clear title and a short description** of one concrete, self-contained change (for
  example, "Add a `/health` endpoint that returns 200 OK").
- Set its **Story point estimate** to a small number at or below the lightweight threshold, which
  defaults to `3`. Use `2` for this tutorial.

You should now have a story with a key like `ACME-101`. Copy that key. That's the only thing we'll
hand to the pipeline.

## Step 4: Run the pipeline with /sdlc:auto

Now for the main event. Run the pipeline on your story key:

```
/sdlc:auto ACME-101
```

Use your real story key in place of `ACME-101`. sdlc will assess the story, then **triage it by
complexity**. Because we set the points to `2`, which is at or under the lightweight threshold, you
should see it classified as **lightweight**.

A lightweight story takes the fast path: **straight to implementation**, with no separate spec or
plan step. sdlc derives the tasks directly from the story description, writes the code, and **opens a
pull request** with the change.

You should see the run finish by reporting an implementation PR. It drives the PR through code review
until it's clean, then leaves it open for you to merge.

## Step 5: Read the comment on the story

Finally, let's confirm the loop back to Jira closed. Open your story (`ACME-101`) in Jira.

You should see a **new comment on the story** noting that implementation is complete, with a
**clickable link to the pull request**. That comment is sdlc telling you the work is ready: the story
you wrote turned into a PR, and the PR is linked right back where you started.

## What you built

You onboarded a repository to sdlc and drove your first Jira story all the way to an open, reviewed
pull request without writing the implementation yourself. Along the way you:

- installed the sdlc plugin and its dependencies,
- onboarded the repo with `/sdlc:init`, which authenticated Jira and scanned your stack,
- created one small story and set its points below the lightweight threshold, and
- ran `/sdlc:auto`, which triaged the story as lightweight, implemented it, opened a PR, and
  commented the PR link back on the story.

From here:

- To run the pipeline on real stories day to day, including larger ones that go through the full
  spec and plan flow, see the how-to guide: docs/how-to/run-the-sdlc-pipeline-on-a-story.md
- To understand what the plugin is and how its pieces fit together, see the concept page:
  docs/concepts/what-is-the-sdlc-plugin.md
