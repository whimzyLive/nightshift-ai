import { getPayload } from 'payload';

import config from '../payload.config';
import { HOME_SLUG, SITE_SETTINGS_SLUG, WHY_SDLC_SLUG } from '../globals/slugs';
import type { Home, SiteSetting, WhySdlc } from '../payload-types';

// The generated shape of every `richText` field value (all richText fields in
// payload-types share this inline structure; `hero.intro` is one of them).
type RichTextValue = NonNullable<NonNullable<WhySdlc['hero']>['intro']>;

/**
 * Builds a minimal, valid Lexical editor state — the shape Payload's default
 * `lexicalEditor()` preset expects for `richText` field values
 * (root > paragraph > text, per Payload's own serialization — confirmed
 * against `lexical`'s ElementNode/TextNode `exportJSON()`). One entry in
 * `paragraphs` becomes one paragraph node.
 */
function textToLexical(paragraphs: string[]): RichTextValue {
  const children = paragraphs.map((text) => ({
    type: 'paragraph',
    format: '' as const,
    indent: 0,
    version: 1,
    direction: 'ltr' as const,
    children: [
      {
        type: 'text',
        format: 0,
        detail: 0,
        mode: 'normal' as const,
        style: '',
        text,
        version: 1,
      },
    ],
  }));

  return {
    root: {
      type: 'root',
      format: '',
      indent: 0,
      version: 1,
      direction: children.length ? 'ltr' : null,
      children,
    },
  } as RichTextValue;
}

// Copy below is sourced verbatim from docs/gtm/site-brief.md (the reviewed
// copy deck) — see that file for section-by-section provenance and the
// founder's open copy decisions (e.g. no invented social proof/metrics).
// Where a Payload field has no direct 1:1 slot for a brief element (e.g.
// Home§3's "Problem" section header has no dedicated `header` field on the
// `problem` group), the closest matching field carries it — the front-end
// components render every field used below; nothing here is dead data.

const siteSettingsData: Omit<SiteSetting, 'id' | 'createdAt' | 'updatedAt'> = {
  installCommand:
    '/plugin marketplace add whimzyLive/nightshift-ai\n/plugin install sdlc@nightshift',
  githubUrl: 'https://github.com/whimzyLive/nightshift-ai',
  githubLabel: 'GitHub',
  navLinks: [
    { label: 'How it works', href: '/#how-it-works' },
    { label: 'Why SDLC', href: '/why-sdlc' },
    { label: 'The team', href: '/#agents' },
    { label: 'FAQ', href: '/#faq' },
  ],
  footerColumns: [
    {
      heading: 'Plugin',
      links: [
        { label: 'How it works', href: '/#how-it-works' },
        { label: 'Ship-while-you-sleep workflow', href: '/#workflow' },
        { label: 'Why SDLC', href: '/why-sdlc' },
        { label: 'The team', href: '/#agents' },
        { label: 'FAQ', href: '/#faq' },
        { label: 'Docs (soon)', href: '/docs' },
      ],
    },
    {
      heading: 'Project',
      links: [
        {
          label: 'GitHub',
          href: 'https://github.com/whimzyLive/nightshift-ai',
        },
        { label: 'Changelog (soon)', href: '/changelog' },
        {
          label: 'MIT License',
          href: 'https://github.com/whimzyLive/nightshift-ai/blob/main/LICENSE',
        },
        {
          label: 'Issues',
          href: 'https://github.com/whimzyLive/nightshift-ai/issues',
        },
      ],
    },
    {
      heading: 'Company',
      links: [{ label: 'whimzyLive', href: 'https://github.com/whimzyLive' }],
    },
  ],
};

const homeData: Omit<Home, 'id' | 'createdAt' | 'updatedAt'> = {
  hero: {
    headline: 'Your AI software team that ships while you sleep',
    subheadline:
      'A Claude Code plugin that turns one terminal into a full delivery team — product manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the spec, plan, code, and review.',
    installCtaLabel: 'Install in 60 seconds',
    starCtaLabel: 'Star nightshift on GitHub',
  },
  proofBar: {
    items: [
      { value: '11', label: 'specialized agents' },
      { value: '10', label: 'slash commands' },
      { value: '60s', label: 'to install' },
      { value: 'Free', label: 'MIT licensed' },
    ],
  },
  problem: {
    eyebrow: 'the other 80%',
    body: "You don't lose time writing code. You lose it around the code. The AI already writes the code. What still eats the sprint is the connective tissue: turning a vague ticket into a real spec, a spec into a plan, keeping the plan honest while you implement, then reviewing the result without rubber-stamping your own work. Coding assistants handle the middle 20%. The other 80% — the process — stays manual, or gets skipped on vibes and shipped unreviewed.",
    points: [
      {
        lead: 'Vague ticket, no spec.',
        body: '"Add auth" becomes whatever you remember at 4pm.',
      },
      {
        lead: 'No enforced lifecycle.',
        body: 'Runbooks exist. Nobody follows them without enforcement.',
      },
      {
        lead: 'Self-review is a rubber stamp.',
        body: "Reviewing your own AI output isn't review.",
      },
    ],
  },
  howItWorks: {
    eyebrow: 'how it works',
    steps: [
      { title: 'PRD + spec', body: 'The ticket becomes a written spec' },
      { title: 'Plan', body: 'An implementation plan, reviewed before code' },
      {
        title: 'Implementation',
        body: 'Code written to the plan, on its own branch',
      },
      {
        title: 'QA review',
        body: 'Independent review by a different agent than the author',
      },
      {
        title: 'PR + ticket comment',
        body: 'A reviewed PR, with the paper trail linked back to the ticket',
      },
    ],
    autoRunCaption:
      '/auto PROJ-142 — small stories (at or under the lightweight threshold, default ≤3 points) skip straight to implementation. Prefer to drive a single stage yourself? Each one has its own verb: /spec, /plan, /impl, /review.',
  },
  workflow: {
    eyebrow: 'your day, split in two',
    blocks: [
      {
        label: 'Day — you refine.',
        body: "Every story gets pre-refined with clear acceptance criteria, and the complicated ones get a full spec. You read the refined stories and specs, decide what's ready, and approve them. You make the calls. You don't write the implementation.",
      },
      {
        label: 'Night — the plugin implements.',
        body: "/auto picks up the tickets and specs you already approved, triages each one, and routes it to the right approach — following the practices your domain agents enforce for that repo (from its project-context.md). Nothing runs on work you haven't signed off.",
      },
      {
        label: 'Morning — you review.',
        body: "You wake up to PRs ready for review. Each one addresses acceptance criteria you already agreed to, or a spec you already approved. You're reading a result you set up, not a surprise.",
      },
    ],
  },
  team: {
    eyebrow: 'the team',
    intro:
      '"Do everything" agents hallucinate across roles and leave no trail. nightshift splits the work across 11 agents, each with a tight charter, its own prompt and tools, and a clean handoff to the next. Narrow charters mean fewer hallucinations and an auditable artifact at every stage.',
    agents: [
      { name: 'Product Manager', role: 'Writes the PRD' },
      { name: 'Architect', role: 'Writes the spec' },
      { name: 'Tech Lead', role: 'Writes the plan' },
      { name: 'Engineers', role: 'Implements the code' },
      { name: 'QA', role: 'Writes the review' },
    ],
  },
  whyDifferent: {
    cards: [
      {
        heading: 'The lifecycle is the product',
        body: 'Spec → plan → implement → review, enforced by the commands and the handoff protocol. Tests are the merge gate. Review is done by a different agent than the one who wrote the code.',
      },
      {
        heading: 'Generic agents, per-repo config',
        body: 'No hardcoding. Every project fact lives in one project-context.md. The same plugin runs a Node monorepo, a Python service, or a mobile app.',
      },
      {
        heading: 'Issue-tracker native',
        body: 'It reads the ticket, derives the branch, plan, and PR, and comments the result back to Jira and GitHub.',
      },
      {
        heading: 'Free, open, yours to fork',
        body: 'Built on open Claude Code primitives, MIT-licensed. Fork it, extend it, swap a role. No lock-in, no paid tier gate.',
      },
    ],
  },
  control: {
    eyebrow: 'control',
    body: "Most AI dev tools abstract the process away until you can't see what you're getting — you only find out once the output lands, then negotiate your way back to what you meant. nightshift runs the opposite way: it keeps the software development lifecycle in front of you, with a hard gate at every phase that returns control before the next step runs.",
    linkLabel: 'Why an SDLC beats one-shot AI →',
    linkHref: '/why-sdlc',
  },
  faq: {
    eyebrow: 'questions',
    items: [
      {
        question: "Isn't this just another AI code-writer wrapper?",
        answer: textToLexical([
          "No. It's a process engine. The wedge is the SDLC, not the code. Assistants do the middle 20%; nightshift runs the other 80% — spec, plan, review, and the handoffs between them.",
        ]),
      },
      {
        question: 'Full ceremony is overkill for a one-line fix.',
        answer: textToLexical([
          '/auto triages by size. Stories at or under the lightweight threshold (default ≤3 points) skip the spec and plan and go straight to implementation.',
        ]),
      },
      {
        question: 'Will it work in my repo and stack?',
        answer: textToLexical([
          'The agents are fully generic. Every project-specific fact lives in one project-context.md file. The same plugin runs across a Node monorepo, a Python service, or a mobile app — you configure it once per repo.',
        ]),
      },
      {
        question: 'What about tool lock-in?',
        answer: textToLexical([
          "It's built on open Claude Code primitives and MIT-licensed. Fork it, extend it, or swap out a role. There's no proprietary runtime to get stuck in.",
        ]),
      },
      {
        question: 'How do I trust agent output?',
        answer: textToLexical([
          'Review is done by a different agent than the author, tests are the merge gate, and every stage leaves an artifact you can read — PRD, spec, plan, review. Nothing merges on vibes.',
        ]),
      },
      {
        question: 'What does it cost?',
        answer: textToLexical([
          "Nothing. It's free and MIT-licensed. Adoption is the only metric we track.",
        ]),
      },
    ],
  },
  finalCta: {
    heading: 'Put a ticket in tonight. Read a reviewed PR in the morning.',
    body: 'Install takes about a minute. Point it at a ticket and watch the spec, plan, code, and review land — with the paper trail linked back where your team already works.',
  },
};

const whySdlcData: Omit<WhySdlc, 'id' | 'createdAt' | 'updatedAt'> = {
  hero: {
    eyebrow: 'why an sdlc',
    h1: 'You decide how it gets built — not the other way around',
    intro: textToLexical([
      'Frameworks, meta-frameworks, and meta-prompts keep promising to do everything for you. The thing they quietly take is control. nightshift is built to give it back.',
    ]),
  },
  argumentSections: [
    {
      heading: 'The trend: abstraction that takes the wheel',
      body: textToLexical([
        "The pitch is always the same: describe an idea, let the tool handle the rest. The cost is visibility. You don't know what you'll get back until the AI has already produced it, and if it built the wrong thing — or the right thing the wrong way — you're stuck in a round of \"no, like this,\" because you never got a say in how it was implemented. Guardrail tools help at the edges, but they still don't give you the control or visibility to steer the work while it's happening.",
      ]),
    },
    {
      heading: 'The answer: the lifecycle you already trust',
      body: textToLexical([
        "Software teams have always shipped the same way: incrementally. Break a large feature into user stories. Spec the hard ones. Implement in small, reviewable steps. That's the software development lifecycle, and it's incremental for a reason — smaller pieces are easier to diagnose, test, release, and control. nightshift enforces those exact principles when you work with AI agents, on open Claude Code primitives.",
      ]),
    },
    {
      heading: 'Hard gates return control at every phase',
      body: textToLexical([
        "Each phase ends at a hard gate that hands control back to you: refine, spec, plan, implement, review. You approve each one before the next begins, so you catch a wrong turn before it's implemented instead of after. Catching it at the gate also means no tokens spent building code you'd have thrown away.",
      ]),
    },
    {
      heading: 'No building it all in one shot',
      body: textToLexical([
        "Software built in one shot gets some things right and some things wrong, and you can't tell which until you've read the whole thing. nightshift doesn't work that way. Work breaks down the way an agile team breaks it down — epic → stories → spec → implementation — so every unit is small enough to review on its own.",
      ]),
    },
    {
      heading: 'It builds the way you would',
      body: textToLexical([
        'With the plugin installed, Claude Code follows these principles by default. Ask it to build something and it works the way you would if you were writing it yourself: refine, spec, implement in steps, review before merge. You stay the developer. It does the typing.',
      ]),
    },
  ],
  faq: {
    items: [
      {
        question: "Isn't this just another guardrail tool?",
        answer: textToLexical([
          'Guardrail tools constrain the output at the edges. nightshift changes the process: each phase ends at a hard gate that returns control to you, so you approve the direction before code is written, not after.',
        ]),
      },
      {
        question: "Doesn't a full lifecycle slow me down?",
        answer: textToLexical([
          "Small stories skip the ceremony — stories at or under the lightweight threshold (default 3 points or fewer) go straight to implementation. The gates exist so you catch a wrong turn before it's built, which is faster than redoing it.",
        ]),
      },
    ],
  },
  finalCta: {
    heading: 'Put the lifecycle back in your hands',
  },
};

async function seed(): Promise<void> {
  const payload = await getPayload({ config });

  // `updateGlobal` overwrites the full document rather than merging arrays,
  // so re-running this script is safe (idempotent) — it always converges on
  // exactly the data below, never duplicates array items.
  await payload.updateGlobal({
    slug: SITE_SETTINGS_SLUG,
    data: siteSettingsData,
  });
  await payload.updateGlobal({ slug: HOME_SLUG, data: homeData });
  await payload.updateGlobal({ slug: WHY_SDLC_SLUG, data: whySdlcData });

  console.log(
    '[seed] site-settings, home, and why-sdlc globals seeded from docs/gtm/site-brief.md',
  );
}

// `payload run` imports this module and exits as soon as the import()
// promise resolves — a fire-and-forget `seed().then(...)` lets the CLI's own
// `process.exit(0)` win the race and kill the process before the DB writes
// land. A top-level `await` keeps the dynamic import() (and therefore the
// CLI) pending until `seed()` genuinely finishes.
try {
  await seed();
} catch (error: unknown) {
  console.error('[seed] failed', error);
  process.exit(1);
}
