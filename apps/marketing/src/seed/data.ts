import type { Faq, WhySdlc } from '../payload-types';

type RichText = Faq['answer'];

type RichTextSegment = string | { code: string };

/**
 * One-paragraph lexical rich text. `{ code }` segments carry the inline
 * `code` mark (Lexical TextNode format bit 16) the handoff uses for terms
 * like `/auto` and `project-context.md` — everything else is plain text.
 */
function richText(segments: RichTextSegment[]): RichText {
  return {
    root: {
      type: 'root',
      direction: 'ltr',
      format: '',
      indent: 0,
      version: 1,
      children: [
        {
          type: 'paragraph',
          direction: 'ltr',
          format: '',
          indent: 0,
          version: 1,
          children: segments.map((segment) => {
            const isCode = typeof segment === 'object';
            return {
              type: 'text',
              text: isCode ? segment.code : segment,
              format: isCode ? 16 : 0,
              style: '',
              mode: 'normal',
              detail: 0,
              version: 1,
            };
          }),
        },
      ],
    },
  } as unknown as RichText;
}

const text = (value: string): RichText => richText([value]);

type FaqSeedRecord = Omit<Faq, 'id' | 'updatedAt' | 'createdAt'>;

/** The 12 canonical FAQ documents, verbatim from the design handoff. Keyed by seedKey for idempotent upsert. */
export const faqSeedData: FaqSeedRecord[] = [
  {
    seedKey: 'positioning-wrapper',
    group: 'positioning',
    question: "Isn't this just another AI code-writer wrapper?",
    answer: text(
      "No. It's a process engine. The wedge is the SDLC, not the code. Assistants do the middle 20%; nightshift runs the other 80% — spec, plan, review, and the handoffs between them.",
    ),
    faqOrder: 1,
    showOnHome: true,
    homeOrder: 1,
    showOnWhySdlc: false,
  },
  {
    seedKey: 'positioning-guardrail',
    group: 'positioning',
    question: "Isn't this just another guardrail tool?",
    answer: text(
      'Guardrail tools constrain the output at the edges. nightshift changes the process: each phase ends at a hard gate that returns control to you, so you approve the direction before code is written, not after.',
    ),
    faqOrder: 2,
    showOnHome: false,
    showOnWhySdlc: true,
    whySdlcOrder: 1,
  },
  {
    seedKey: 'workflow-approve-every-step',
    group: 'workflow-control',
    question: 'Do I have to approve every step?',
    answer: text(
      'Only where you configure it. approval_mode is per-repo: assisted waits for you at every gate, auto waits only at spec and review, full-auto runs the whole pipeline on your standing config. The gates exist for you — not the other way around.',
    ),
    faqOrder: 3,
    showOnHome: false,
    showOnWhySdlc: false,
  },
  {
    seedKey: 'workflow-full-ceremony',
    group: 'workflow-control',
    question: 'Full ceremony is overkill for a one-line fix.',
    answer: text(
      '/auto triages by type and size. Bugs never get a spec or plan — straight to implementation. Stories at or under the lightweight threshold (default ≤3 points) skip the ceremony the same way. Only larger stories earn the full spec → plan → review path.',
    ),
    faqOrder: 4,
    showOnHome: true,
    homeOrder: 2,
    homeAnswer: richText([
      { code: '/auto' },
      ' triages by size. Stories at or under the lightweight threshold (default ≤3 points) skip the spec and plan and go straight to implementation.',
    ]),
    showOnWhySdlc: false,
  },
  {
    seedKey: 'workflow-overnight',
    group: 'workflow-control',
    question: 'What actually happens overnight?',
    answer: text(
      'Only work you already approved. You refine and sign off stories by day; /auto picks them up, routes each by your config, and implements on its own branch. You wake up to PRs that answer acceptance criteria you agreed to — a result you set up, not a surprise.',
    ),
    faqOrder: 5,
    showOnHome: false,
    showOnWhySdlc: false,
  },
  {
    seedKey: 'workflow-slow-me-down',
    group: 'workflow-control',
    question: "Doesn't a full lifecycle slow me down?",
    answer: text(
      'Small stories skip the ceremony entirely, and the gates exist so you catch a wrong turn before it is built — which is faster than redoing it. No tokens spent building code you would have thrown away.',
    ),
    faqOrder: 6,
    showOnHome: false,
    showOnWhySdlc: true,
    whySdlcOrder: 2,
    whySdlcAnswer: text(
      "Small stories skip the ceremony — stories at or under the lightweight threshold (default 3 points or fewer) go straight to implementation. The gates exist so you catch a wrong turn before it's built, which is faster than redoing it.",
    ),
  },
  {
    seedKey: 'setup-repo-stack',
    group: 'setup-stack',
    question: 'Will it work in my repo and stack?',
    answer: text(
      'The agents are fully generic. Every project-specific fact lives in one project-context.md file, plus optional per-agent override files. The same plugin runs across a Node monorepo, a Python service, or a mobile app — you configure it once per repo.',
    ),
    faqOrder: 7,
    showOnHome: true,
    homeOrder: 3,
    homeAnswer: richText([
      'The agents are fully generic. Every project-specific fact lives in one ',
      { code: 'project-context.md' },
      ' file. The same plugin runs across a Node monorepo, a Python service, or a mobile app — you configure it once per repo.',
    ]),
    showOnWhySdlc: false,
  },
  {
    seedKey: 'setup-need-jira',
    group: 'setup-stack',
    question: 'Do I need Jira?',
    answer: text(
      "It's issue-tracker native: stories are read from Jira (via acli) and results are commented back to the ticket and the GitHub PR (via gh). Your tracker stays the source of truth — the paper trail lands where your team already works.",
    ),
    faqOrder: 8,
    showOnHome: false,
    showOnWhySdlc: false,
  },
  {
    seedKey: 'trust-agent-output',
    group: 'trust-quality',
    question: 'How do I trust agent output?',
    answer: text(
      'Review is done by a different agent than the author, tests are the merge gate, and every stage leaves an artifact you can read — PRD, spec, plan, review. Nothing merges on vibes.',
    ),
    faqOrder: 9,
    showOnHome: true,
    homeOrder: 4,
    showOnWhySdlc: false,
  },
  {
    seedKey: 'trust-paper-trail',
    group: 'trust-quality',
    question: 'What does the paper trail look like?',
    answer: text(
      'One readable document per phase: a PRD in docs/features/, a spec and plan in docs/superpowers/, review learnings in team memory, and a PR linked back to the ticket. Every decision is diffable.',
    ),
    faqOrder: 10,
    showOnHome: false,
    showOnWhySdlc: false,
  },
  {
    seedKey: 'cost-what-does-it-cost',
    group: 'cost-license',
    question: 'What does it cost?',
    answer: text(
      "Nothing. It's free and MIT-licensed. Adoption is the only metric we track.",
    ),
    faqOrder: 11,
    showOnHome: true,
    homeOrder: 5,
    showOnWhySdlc: false,
  },
  {
    seedKey: 'cost-tool-lock-in',
    group: 'cost-license',
    question: 'What about tool lock-in?',
    answer: text(
      "It's built on open Claude Code primitives and MIT-licensed. Fork it, extend it, or swap out a role. There's no proprietary runtime to get stuck in.",
    ),
    faqOrder: 12,
    showOnHome: false,
    showOnWhySdlc: false,
  },
];

type WhySdlcSeedData = Omit<WhySdlc, 'id' | 'updatedAt' | 'createdAt'>;

/** The Why-SDLC page's editorial argument copy, verbatim from the design handoff. */
export const whySdlcSeedData: WhySdlcSeedData = {
  intro: {
    eyebrow: '// why an sdlc',
    heading: 'You decide how it gets built — not the other way around',
    lead: text(
      'Frameworks, meta-frameworks, and meta-prompts keep promising to do everything for you. The thing they quietly take is control. nightshift is built to give it back.',
    ),
    scrollHint:
      'five sections · five gates — they light as you read, and the panel beside the text shows each argument ↓',
  },
  arguments: [
    {
      eyebrow: '// 01 · the trend',
      heading: 'Abstraction that takes the wheel',
      body: text(
        "The pitch is always the same: describe an idea, let the tool handle the rest. The cost is visibility. You don't know what you'll get back until the AI has already produced it, and if it built the wrong thing — or the right thing the wrong way — you're stuck in a round of \"no, like this,\" because you never got a say in how it was implemented. Guardrail tools help at the edges, but they still don't give you the control or visibility to steer the work while it's happening.",
      ),
    },
    {
      eyebrow: '// 02 · the answer',
      heading: 'The lifecycle you already trust',
      body: text(
        "Software teams have always shipped the same way: incrementally. Break a large feature into user stories. Spec the hard ones. Implement in small, reviewable steps. That's the software development lifecycle, and it's incremental for a reason — smaller pieces are easier to diagnose, test, release, and control. nightshift enforces those exact principles when you work with AI agents, on open Claude Code primitives.",
      ),
    },
    {
      eyebrow: '// 03 · hard gates',
      heading: 'Hard gates return control at every phase',
      body: text(
        "Each phase ends at a hard gate that hands control back to you: refine, spec, plan, implement, review. You approve each one before the next begins, so you catch a wrong turn before it's implemented instead of after. Catching it at the gate also means no tokens spent building code you'd have thrown away.",
      ),
    },
    {
      eyebrow: '// 04 · no one-shot',
      heading: 'No building it all in one shot',
      body: text(
        "Software built in one shot gets some things right and some things wrong, and you can't tell which until you've read the whole thing. nightshift doesn't work that way. Work breaks down the way an agile team breaks it down — epic → stories → spec → implementation — so every unit is small enough to review on its own.",
      ),
    },
    {
      eyebrow: '// 05 · builds like you',
      heading: 'It builds the way you would',
      body: text(
        'With the plugin installed, Claude Code follows these principles by default. Ask it to build something and it works the way you would if you were writing it yourself: refine, spec, implement in steps, review before merge. You stay the developer. It does the typing.',
      ),
    },
  ],
};
