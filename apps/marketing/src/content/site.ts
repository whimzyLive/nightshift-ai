/* nightshift marketing site — copy & structured data.
 * Sourced verbatim from docs/gtm/site-brief.md (§1 IA, §2 copy deck,
 * §3 JSON-LD). Do not reword gated copy here — update the brief first.
 */

export const REPO_URL = 'https://github.com/whimzyLive/nightshift-ai';
export const CANONICAL_URL = REPO_URL;

export const INSTALL_COMMANDS = [
  '/plugin marketplace add whimzyLive/nightshift-ai',
  '/plugin install sdlc@nightshift',
] as const;

export const PIPELINE_CAPTION =
  'Jira ticket → spec → plan → implementation → review → PR';

export const NAV_LINKS = [
  { label: 'How it works', href: '#how-it-works' },
  { label: 'The team', href: '#agents' },
  { label: 'FAQ', href: '#faq' },
];

export const FOOTER_COLUMNS = [
  {
    title: 'Plugin',
    items: [
      { label: 'How it works', href: '#how-it-works' },
      { label: 'The team', href: '#agents' },
      { label: 'FAQ', href: '#faq' },
      { label: 'Docs (soon)', href: '#' },
    ],
  },
  {
    title: 'Project',
    items: [
      { label: 'GitHub', href: REPO_URL },
      { label: 'Changelog (soon)', href: '#' },
      { label: 'MIT License', href: `${REPO_URL}/blob/main/LICENSE` },
      { label: 'Issues', href: `${REPO_URL}/issues` },
    ],
  },
  {
    title: 'Company',
    items: [{ label: 'whimzyLive', href: 'https://github.com/whimzyLive' }],
  },
];

export const PROOF_BAR_ITEMS = [
  '11 specialized agents',
  '10 slash commands',
  'install in 60 seconds',
  'free · MIT',
];

export const PROBLEM_SUBPOINTS = [
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
];

export const AUTO_RUN_STEPS = [
  { step: '1', runs: 'PRD + spec', get: 'The ticket becomes a written spec' },
  {
    step: '2',
    runs: 'Plan',
    get: 'An implementation plan, reviewed before code',
  },
  {
    step: '3',
    runs: 'Implementation',
    get: 'Code written to the plan, on its own branch',
  },
  {
    step: '4',
    runs: 'QA review',
    get: 'Independent review by a different agent than the author',
  },
  {
    step: '5',
    runs: 'PR + ticket comment',
    get: 'A reviewed PR, with the paper trail linked back to the ticket',
  },
];

/** The 11-agent roster — design-system product data (references/components.md). */
export const TEAM = [
  {
    name: 'product-manager',
    owns: 'Vague idea → PRD with binary acceptance criteria',
    tone: 'accent' as const,
  },
  {
    name: 'solutions-architect',
    owns: 'PRD → technical design / spec',
    tone: 'accent' as const,
  },
  {
    name: 'scrum-master',
    owns: 'Story slicing, mapping, splitting',
    tone: 'info' as const,
  },
  {
    name: 'tech-lead',
    owns: 'Spec → ordered, verifiable implementation plan',
    tone: 'info' as const,
  },
  {
    name: 'principal-engineer',
    owns: 'Orchestrates the build, dispatches domain agents in dependency order',
    tone: 'accent' as const,
  },
  {
    name: 'platform-engineer',
    owns: 'Backend / infrastructure / serverless',
    tone: 'cyan' as const,
  },
  { name: 'web-engineer', owns: 'Web UI', tone: 'cyan' as const },
  {
    name: 'mobile-engineer',
    owns: 'Mobile apps',
    tone: 'cyan' as const,
    standby: true,
  },
  {
    name: 'database-administrator',
    owns: 'Schema, migrations, data',
    tone: 'cyan' as const,
  },
  {
    name: 'sync-engineer',
    owns: 'Offline / sync layer',
    tone: 'cyan' as const,
    standby: true,
  },
  {
    name: 'qa-engineer',
    owns: 'Always-on review → quality gate → AC verification → PR',
    tone: 'green' as const,
  },
];

export const VALUE_CARDS = [
  {
    header: 'The lifecycle is the product',
    body: 'Spec → plan → implement → review, enforced by the commands and the handoff protocol. Tests are the merge gate. Review is done by a different agent than the one who wrote the code.',
  },
  {
    header: 'Generic agents, per-repo config',
    body: 'No hardcoding. Every project fact lives in one project-context.md. The same plugin runs a Node monorepo, a Python service, or a mobile app.',
  },
  {
    header: 'Issue-tracker native',
    body: 'It reads the ticket, derives the branch, plan, and PR, and comments the result back to Jira and GitHub.',
  },
  {
    header: 'Free, open, yours to fork',
    body: 'Built on open Claude Code primitives, MIT-licensed. Fork it, extend it, swap a role. No lock-in, no paid tier gate.',
  },
];

export const FAQ_ITEMS = [
  {
    q: "Isn't this just another AI code-writer wrapper?",
    a: "No. It's a process engine. The wedge is the SDLC, not the code. Assistants do the middle 20%; nightshift runs the other 80% — spec, plan, review, and the handoffs between them.",
  },
  {
    q: 'Full ceremony is overkill for a one-line fix.',
    a: '/auto triages by size. Stories at or under the lightweight threshold (default ≤3 points) skip the spec and plan and go straight to implementation.',
  },
  {
    q: 'Will it work in my repo and stack?',
    a: 'The agents are fully generic. Every project-specific fact lives in one project-context.md file. The same plugin runs across a Node monorepo, a Python service, or a mobile app — you configure it once per repo.',
  },
  {
    q: 'What about tool lock-in?',
    a: "It's built on open Claude Code primitives and MIT-licensed. Fork it, extend it, or swap out a role. There's no proprietary runtime to get stuck in.",
  },
  {
    q: 'How do I trust agent output?',
    a: 'Review is done by a different agent than the author, tests are the merge gate, and every stage leaves an artifact you can read — PRD, spec, plan, review. Nothing merges on vibes.',
  },
  {
    q: 'What does it cost?',
    a: "Nothing. It's free and MIT-licensed. Adoption is the only metric we track.",
  },
];

/** §3 JSON-LD — embedded verbatim on the home page. */
export const JSON_LD = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'SoftwareApplication',
      '@id': `${REPO_URL}#software`,
      name: 'nightshift',
      applicationCategory: 'DeveloperApplication',
      applicationSubCategory: 'Claude Code plugin',
      operatingSystem: 'Any (runs inside Claude Code)',
      description:
        'A free, MIT-licensed Claude Code plugin that turns one terminal into a full software-delivery team — product manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the spec, plan, code, and review automatically.',
      url: REPO_URL,
      downloadUrl: REPO_URL,
      license: 'https://opensource.org/licenses/MIT',
      isAccessibleForFree: true,
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'USD',
      },
      featureList: [
        '11 specialized agents with tight charters',
        '10 slash commands',
        'Enforced lifecycle: spec, plan, implement, review',
        'Issue-tracker native (Jira and GitHub)',
        'Generic agents configured per repo via project-context.md',
        'Independent review by a different agent than the author',
      ],
      author: { '@id': 'https://github.com/whimzyLive#org' },
      publisher: { '@id': 'https://github.com/whimzyLive#org' },
    },
    {
      '@type': 'Organization',
      '@id': 'https://github.com/whimzyLive#org',
      name: 'whimzyLive',
      url: 'https://github.com/whimzyLive',
      sameAs: [REPO_URL],
    },
    {
      '@type': 'FAQPage',
      '@id': `${REPO_URL}#faq`,
      mainEntity: [
        {
          '@type': 'Question',
          name: "Isn't nightshift just another AI code-writer wrapper?",
          acceptedAnswer: {
            '@type': 'Answer',
            text: "No. It's a process engine. The wedge is the SDLC, not the code. Coding assistants handle the middle 20% — writing the code. nightshift runs the other 80%: spec, plan, review, and the handoffs between them.",
          },
        },
        {
          '@type': 'Question',
          name: 'Is full ceremony overkill for small fixes?',
          acceptedAnswer: {
            '@type': 'Answer',
            text: 'The /auto command triages by size. Stories at or under the lightweight threshold (default 3 points or fewer) skip the spec and plan and go straight to implementation.',
          },
        },
        {
          '@type': 'Question',
          name: 'Will nightshift work in my repo and stack?',
          acceptedAnswer: {
            '@type': 'Answer',
            text: 'The agents are fully generic. Every project-specific fact lives in one project-context.md file. The same plugin runs across a Node monorepo, a Python service, or a mobile app.',
          },
        },
        {
          '@type': 'Question',
          name: 'Is there tool or vendor lock-in?',
          acceptedAnswer: {
            '@type': 'Answer',
            text: 'No. nightshift is built on open Claude Code primitives and MIT-licensed. You can fork it, extend it, or swap out a role.',
          },
        },
        {
          '@type': 'Question',
          name: 'How do I trust the agent output?',
          acceptedAnswer: {
            '@type': 'Answer',
            text: 'Review is done by a different agent than the one that wrote the code, tests are the merge gate, and every stage leaves an artifact you can read: PRD, spec, plan, and review.',
          },
        },
        {
          '@type': 'Question',
          name: 'What does nightshift cost?',
          acceptedAnswer: {
            '@type': 'Answer',
            text: 'Nothing. nightshift is free and MIT-licensed. There is no paid tier today; adoption is measured in installs and GitHub stars.',
          },
        },
      ],
    },
  ],
} as const;
