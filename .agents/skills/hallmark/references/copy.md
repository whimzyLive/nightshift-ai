# Copy

Words are part of the design. A great layout with stock copy looks generic. Tight copy in an average layout reads as considered.

## Principles

- **Specific verbs.** "Save changes" beats "OK" beats "Submit".
- **Labels describe.** "Email address" beats "Email".
- **Link text stands alone.** "View pricing plans" beats "Click here".
- **Errors are instructions.** Describe what broke, why, how to fix — in that order.
- **Active voice.** "We couldn't find your account" beats "Your account could not be found".
- **Consistency.** Pick one of "Delete" or "Remove". Pick one of "Sign in" or "Log in". Use it everywhere.

## Buttons

Use the verb for the action the button performs.

Good: `Save changes`, `Create account`, `Send invitation`, `Copy link`, `Open file`.
Bad: `OK`, `Submit`, `Click here`, `Continue` (only as the secondary button of a multi-step flow).

## Error messages

Three parts:

1. **What happened.** Past tense, factual. "That card was declined."
2. **Why, if known.** "Your bank flagged the charge."
3. **What to do.** Imperative. "Try another card, or contact your bank."

Never apologetic for the _user's_ input. Don't say "Oops!" on a validation error. A form that won't accept a value should explain the value, not perform embarrassment.

## Empty states

Three beats:

1. One line naming what's empty. "No projects yet."
2. One line on why this matters / what projects are. "Projects group your tasks and team."
3. One button. The single next action. "Create a project".

## Loading

- Short wait: spinner with no text.
- Medium wait (>2s): spinner + "Loading…".
- Long wait (>10s): spinner + progress indication + an honest label — "Compiling (this can take a minute)."

## Microcopy bans

- "Click here." Link text must stand alone.
- "Oops!", "Uh oh!", "Something went wrong." Name the thing that broke.
- "Enter your email below." If the input is below, you don't need to say so.
- Exclamation marks in error states.
- Humour in frustration paths (forgot-password, payment-failed, account-locked).
- Stock placeholder names: Jane Doe, John Smith, Lorem Ipsum (unless the page is a lorem-ipsum tool).
- Startup clichés in product copy: Acme, Nexus, Unleash, Seamless, Supercharge, Transform, Elevate, Empower, Delight, Magical.
- Marketing copy that promises a feeling without naming a feature. "Experience the power of \_\_\_" is empty.

## Proper typography

- Curly quotes: `"Hello"`, `'word'`.
- Em-dash for interruption: `—` (U+2014). En-dash for ranges: `10–20` (U+2013). Never `--`.
- Ellipsis: `…` (U+2026). Never `...`.
- Apostrophe: `’`. Never the prime `'`.
- Non-breaking space before units: `10 kg`, `5 min` (use `&nbsp;` or U+00A0).

If the text is loaded from a CMS, configure Smart Quotes in the CMS. If it's hard-coded, write it correctly.

---

## Voice samples per tone

The skill bends toward distribution-default copy ("Built for the modern team", "Unleash your X", "Where A meets B") unless given non-default voices to imitate. The samples below are _real opening lines_ from sites that defy that distribution. **Imitate the kind of specificity** — named places, named dates, named verticals, refusal of metaphor, refusal of the verb — not the wording. The tone column maps to the seven tones the design-context gate (see [`SKILL.md`](../SKILL.md) Step 1) commits the user to.

### Editorial

Three voice patterns: _date-anchored_, _refusal of the verb_, _enumerative_.

- _"Creative direction, design and type for culture since 2003."_ — apracticeforeverydaylife.com — date + named verticals
- _"A monthly art publication featuring contributions by some of the most engaged thinkers working today."_ — e-flux.com/journal — uses cadence (_monthly_) and a verb (_featuring_) that's specific
- _"A thing well made."_ — klim.co.nz — refusal of the verb, treats design as material
- _"Frieze elevates the provocative and brilliant leading voices who shape and challenge today's art world."_ — frieze.com — uses _challenge_ instead of _empower_
- _"We design everything for everyone."_ — pentagram.com — refusal of marketing verbs; democratic claim
- _"Writer + Photographer."_ — craigmod.com — three words, two roles, no padding
- _"Type, set with care."_ — Hallmark Specimen — three words; the comma is the design
- _"I'm a French design technologist based in London. I make websites and fonts, amongst other physical and digital artefacts."_ — mathieutriay.com — named place, named deliverables, "artefacts" signals craft

### Brutalist

Three voice patterns: _flat declarative_, _refusal of metaphor_, _direct address with consequence_.

- _"The product development system for teams and agents."_ — linear.app — flat declarative; no flourish, no "powered by AI"
- _"Resend is the email API for developers. Send transactional and marketing emails at scale with a simple, modern API."_ — resend.com — names the form factor, the audience, and what it does
- _"Purpose-built for planning and building products. Designed for the AI era."_ — linear.app — names the era plainly, no euphemism
- _"WE ARE A STUDIO. WE ARE NOT A PLATFORM."_ — Hallmark Meridian (test 04) — defines by refusal, all caps
- _"We design products that last twelve years. We do not design products that need replacing every two."_ — concrete number, paired declaration
- _"A toolkit for assembling new worlds from the scraps of the old."_ — are.na — second-position copy that breaks template
- _"NO COMPROMISE."_ — Hallmark Brutal — two words; the period is the design
- _"We will not put our work behind a chatbot. We will answer the email ourselves."_ — declarative refusal, two short sentences

### Soft

Three voice patterns: _poetic restraint_, _passion via enumeration_, _vulnerability with proof_.

- _"It's about time."_ — cron.com — pun without winking; restraint
- _"Time is our most precious resource."_ — Notion Calendar — opens on the philosophical premise, then gets concrete
- _"Designer for the Web (v. XIX)."_ — lynnandtonic.com — version number signals craft-in-progress
- _"Design engineer creating software that makes people feel something."_ — rauno.me — emotional outcome over feature list; "feel something" avoids genre cliché
- _"All I want to do is build websites. Typography, motion design, copywriting, performance — the web is an endless medium of opportunity."_ — paco.me — passion via enumeration; vulnerability ("scratched the surface")
- _"I craft UI demos that explore the power of the web and help others sharpen their skills."_ — jhey.dev — names the verb (_craft_), names the audience (_others_)
- _"Soft, but exact."_ — Hallmark Hum — two short adjectives, one comma, full stop
- _"This page is soft because the surface should be soft. The rules underneath are not."_ — pairs claim with refusal

### Technical

Three voice patterns: _spec-embedded prose_, _measured language_, _data-first opening_.

- _"The 14-inch MacBook Pro with M5 brings serious speed and advanced on-device AI to the personal, professional, and creative work you do every day."_ — apple.com — spec embedded in prose; "serious speed" is measured language
- _"434 total posts. New CSS you feel like you could use today."_ — nerdy.dev (Adam Argyle) — data-first; "feel like" suggests genuine utility
- _"$ streampipe parse access.log --filter status=5xx | jq"_ — Streampipe (test 02) — open on a real command, not a marketing claim
- _"Open the trace, find the span, fix the regression. No glossary required."_ — Tracejam (test 05) — three concrete verbs, then a refusal
- _"From stdin, through the pipe, into your dashboard."_ — names the data path; refuses abstraction
- _"23 spans · 4 services · 482 ms."_ — Tracejam mockup — data is the headline
- _"Read anything that emits lines. Files, pipes, sockets, kubectl logs."_ — names the inputs, refuses generality
- _"Drop-in OTLP. No agent, no sidecar."_ — pairs claim with refusal of common alternatives

### Luxury

Three voice patterns: _heritage with specifics_, _refusal as sophistication_, _named scale_.

- _"The world's most acclaimed creative collective, where 23 partners work independently and collaboratively to shape the future of design."_ — pentagram.com — heritage (implied longevity), named scale (23 partners)
- _"By appointment."_ — atelier-style — refusal as gatekeeping
- _"A study in the senses."_ — Hallmark Atelier — single nominal phrase, comma-free
- _"A page should arrive like a person — composed, deliberate, in good clothes."_ — Hallmark Atelier — analogy treats the page as social
- _"With pleasure, you are most welcome."_ — Hallmark Editorial salutation — formal address
- _"Restraint, repeated, becomes a signature."_ — Hallmark Atelier — three commas, four words, philosophical
- _"A studied hand."_ — three words; the determiner does the work
- _"A small, opinionated craftsmanship engine that argues with your AI assistant on your behalf — and wins."_ — Hallmark Atelier — names the role precisely, embraces the conflict

### Playful

Three voice patterns: _analogy via pop-culture_, _food/sensory metaphor_, _anticipated reaction_.

- _"Playlists, but for ideas."_ — are.na — analogy that's also useful
- _"Internet memory palace."_ — are.na — three-word noun phrase, structural metaphor
- _"Devouring details. Nourishing novelty. Deploying excellence."_ — rauno.me — alliteration; food + tech metaphor
- _"The kind that make you say, 'Wait, how did you do that?'"_ — jhey.dev — direct address, anticipates the reader's reaction
- _"Built to ship."_ — Hallmark Sport — three words, declarative, with a verb that's a verb
- _"Ready? You are two minutes from shipping."_ — Hallmark Sport — a question, then a number
- _"design like print: warm, off-register, intentional."_ — Hallmark Riso — lowercase + colon + three modifiers
- _"this is not a page that pretends to be paper. it is a page that remembers paper."_ — Riso — refuses the imitation framing

### Austere

Three voice patterns: _extreme abbreviation_, _principle as opening_, _refusal of marketing language_.

- _"Hello."_ — Hallmark Coral salutation — one word; the period is the design
- _"This is a page that doesn't try."_ — Coral — declares the position openly
- _"Things Become Other Things."_ — craigmod.com — three words; treats brand as essay title
- _"Lightness above weightiness, elevate everyone you encounter."_ — craigmod.com — principle-first positioning
- _"A quiet skill."_ — Hallmark Coral — three words; the article is doing work
- _"Software can be soft and exact at once. That's the trick."_ — Hallmark Hum — names the contradiction, names the resolution
- _"One HTML file."_ — Anya (test 06) footer — three words; the count is the boast
- _"This page doesn't move."_ — names the design decision openly

---

## Banned opening lines (anti-patterns)

These phrases appear across distribution-default LLM copy and reach for none of the specificity above. **Banned outright** — if you find yourself reaching for one, replace it with one of the patterns from the tone above.

| Phrase                           | Why it fails                                              |
| -------------------------------- | --------------------------------------------------------- |
| _"Built for the modern team"_    | Vague; assumes no specifics; temporal marketing           |
| _"Unleash your [X]"_             | Hyperbolic; software can't unleash anything               |
| _"Where X meets Y"_              | False synthesis; creative laziness                        |
| _"Empower your..."_              | Missionary language; avoids concrete benefit              |
| _"Reimagine the way you..."_     | Suggests dissatisfaction before explaining need           |
| _"Supercharge your workflow"_    | Energy metaphor without mechanics                         |
| _"Innovative solutions"_         | Meaningless; every product claims innovation              |
| _"Seamless integration"_         | "Seamless" has no antonym; signals non-specificity        |
| _"In today's digital landscape"_ | Temporal hand-wave; assumes the reader needs orientation  |
| _"Next-generation"_              | Implies predecessor inadequacy; offers no differentiation |

If the brief gives you nothing to work with for an opening line, _say so to the user_ and ask one question that elicits a specific noun, verb, or place. The user knows their product; the model is not allowed to invent specificity.
