# Wireframe kit — Balsamiq-style draft boards

<!-- notation: `:=` define, `->` leads-to, `|` first-match-wins alternative, ASSERT/ELSE guard. Full legend: refs/pseudocode-notation.md -->

What `/sdlc:design --draft` draws with. The designer (`agents/designer.md`) writes screens in kit classes, `scripts/wireframe-build.sh` assembles standalone pages, `scripts/wireframe-check.sh` lints them. Boards play in a plain browser: links are plain `<a href>` between pages, no canvas, no script. Rules: `refs/design-workflow.md` (Wireframe drafts).

## Files

| File | Use |
| --- | --- |
| `wireframe.css` | the whole look; never restyled, never extended per project |
| `strokes/box-lg.svg`, `box-sm.svg`, `box-dash.svg` | hand-drawn borders the CSS loads by relative URL, so `strokes/` sits next to the pages |
| `skeleton.web.html` | browser frame, 1440x900; slots `{{TITLE}}` `{{URL}}` `{{SHELL}}` `{{MAIN}}` |
| `skeleton.phone.html` | device frame, 438x892 outer, 390 wide screen; slots `{{TITLE}}` `{{MAIN}}` `{{NAV}}` |

Font: Balsamiq Sans, `family=Balsamiq+Sans:wght@400;700` on Google Fonts (the skeletons link it).

## Class vocabulary

| Class | Use |
| --- | --- |
| `.wf` | root of a board; `.wf.phone` for a phone board |
| `.chrome` `.lights` `.url` | browser frame: title bar, three dots, address field |
| `.bodyrow` | row under the chrome: shell plus main |
| `.side` `.logo` `.nav` `.cap` | sidebar: container, product name, link (`.nav.on` current), small section caption |
| `.main` | the page content area beside the sidebar |
| `.sk` `.sk2` | sketched box: a panel, card, table frame (`.sk2` the same, for a nested box) |
| `.btn` `.btn.p` `.btn.s` | button; `.p` primary (blue), `.s` secondary; always put on the `<a>` itself |
| `.in` | text field, select or search input, with its placeholder as text |
| `.chip` `.chip.on` | filter chip, selected |
| `.kbd` | keyboard hint inside a button or field |
| `.tag` `.tag.w` | status badge; `.w` warning (yellow) |
| `.lbl` | field label |
| `table` `th` `td` `.r` | table; `.r` right-aligns a cell |
| `.bar` + `<i style="width:62%">` | progress or budget bar |
| `.tabs` `.tab` `.tab.on` | tab group, selected tab |
| `.stat` `.big` | stat tile and its number |
| `.radio` `.dot` `.dot.on` | choice card and its radio dot |
| `.box` `.box.on` | checkbox |
| `.note` | dashed callout for information in the page itself |
| `.sticky` | yellow sticky note for an open question or a rule a reviewer should see; absolutely placed by `right`/`bottom`/`top`/`left` |
| `.cols` `.col` | bar chart: columns with inline `height` |
| `.rowx` `.sp` `.mut` `.xs` | flex row, flex spacer, muted text, small text |
| `.device` `.screen` `.bottomnav` `.listrow` | phone: device frame, screen, bottom nav, list row (an `<a>`) |

Allowed beyond classes: inline layout only (`display`, `flex*`, `grid*`, `gap`, sizes, `padding`, `margin`, `align*`, `justify*`, `position` with offsets, `overflow`, `text-align`). No colour, no `<style>`, no script. Greyscale plus the kit's blue (selected, primary) and yellow (notes). Icons are inline stroke SVG (`stroke="currentColor"`, 24 viewBox).

## Working folder

```text
WF_DIR := $(bash scripts/tmp-dir.sh)/wireframes       # git-ignored; never the repo; a hand-off: deleted after a canvas publish, the canvas is the only copy
WF_DIR/parts/shell.side.html                           # web nav, written once per run
WF_DIR/parts/shell.bottomnav.html                      # phone nav, written once per run
WF_DIR/parts/page-<template>.main.html                 # one starter per page template of the vocabulary
WF_DIR/<screen>.main.html                              # web main slot  -> <screen>.html
WF_DIR/<screen>.phone.main.html                        # phone screen   -> <screen>.phone.html
first line of a fragment := <!-- wf title: <t> | nav: <data-nav key> | url: <path> -->
bash scripts/wireframe-build.sh WF_DIR                 # copies the css and strokes, assembles every page, marks the current nav link
bash scripts/wireframe-check.sh WF_DIR --vocabulary <Pattern vocabulary file>
```

```text
shell part := the nav written once with the project's real nav items; each link `<a class="nav" data-nav="<key>" href="<screen>.html">` (`href="#"` while its screen is not drawn)
              the part carries data-pattern; pages never carry their own copy: the check fails a page whose shell differs from the part
project parts := shell + page starters, generated on the first --draft run of a project from the vocabulary's page templates and the app's nav
                 about 10 to 15 blocks in all; no wireframe twin per component; later runs reuse them and add only what is missing
```

## Patterns

```text
structural block := an element with class .sk .sk2 .note .stat .cols .tabs .side .bottomnav -> data-pattern="<Pattern vocabulary name>" | "?" for a gap, never an invented name
no visible pattern label on a box; `?` boxes are listed in the return and become gaps in --plan
optional vocabulary column `Wireframe` := the kit classes or snippet that draw that pattern; a row without one is drawn as a plain `.sk` box
```

## Linking

```text
control that navigates -> <a class="btn p" href="<screen>.html">; phone boards link to <screen>.phone.html
control that goes nowhere in this draft -> href="#"; wireframe-check.sh prints it as NOTLINKED, the designer lists it in the return
never a <button> inside an <a>: the click is swallowed on a canvas
```

## Worked example — web list screen (`projects.main.html`)

```html
<!-- wf title: Projects | nav: projects | url: app.example/projects -->
<div class="rowx"><div><h1>Projects</h1><span class="mut">7 active, 3 archived</span></div><span class="sp"></span>
  <a class="btn p" href="project-new.html">New project <span class="kbd">C P</span></a></div>
<div class="rowx"><div class="in" style="width:320px">Search projects <span class="sp"></span><span class="kbd">/</span></div>
  <span class="chip">Client</span><span class="chip on">Status: Active</span><span class="sp"></span><span class="xs mut">Sorted by name</span></div>
<div class="sk" data-pattern="List page" style="padding:6px 14px;flex:1;min-height:0"><table>
  <thead><tr><th>Project</th><th>Client</th><th>Budget used</th><th class="r">This week</th></tr></thead>
  <tbody>
  <tr><td><a href="project-overview.html">Harbour Street fit-out</a> <span class="xs mut">HSF-01</span></td><td>Calloway Property Group</td>
    <td><div class="rowx"><div class="bar"><i style="width:62%"></i></div><span class="xs">62%</span></div></td><td class="r">41 h</td></tr>
  <tr><td>Website rebuild <span class="tag w">Near budget</span></td><td>Tidewater Dental</td>
    <td><div class="rowx"><div class="bar"><i style="width:88%"></i></div><span class="xs">88%</span></div></td><td class="r">26 h</td></tr>
  </tbody></table></div>
<div class="sticky" style="right:70px;bottom:120px">Members see only the projects they are on, and no money columns.</div>
```

## Worked example — phone screen (`projects.phone.main.html`)

```html
<!-- wf title: Projects (phone) | nav: projects -->
<div class="rowx"><h1>Projects</h1><span class="sp"></span><a class="btn p" href="project-new.phone.html">New</a></div>
<div class="in">Search projects</div>
<div class="rowx"><span class="chip on">Active</span><span class="chip">Client</span><span class="chip">Manager</span></div>
<div class="sk" data-pattern="List page" style="padding:4px 12px;flex:1;min-height:0">
  <a class="listrow" href="project-overview.phone.html"><div style="flex:1"><div>Harbour Street fit-out</div><div class="xs mut">Calloway Property Group</div>
    <div class="bar" style="width:100%;margin-top:6px"><i style="width:62%"></i></div></div><span class="xs">62%</span></a>
</div>
```

The phone nav part: `<nav class="bottomnav" data-pattern="Bottom nav" aria-label="Main"><a data-nav="projects" href="projects.phone.html">Projects</a>...</nav>`.
