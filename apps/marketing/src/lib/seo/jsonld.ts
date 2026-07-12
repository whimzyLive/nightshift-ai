import { faqAnswerToPlaintext } from './faq-plaintext';

import type { SerializedEditorState } from '@payloadcms/richtext-lexical/lexical';

export interface JsonLdOffer {
  '@type': 'Offer';
  price: string;
  priceCurrency: string;
}

export interface SoftwareApplicationNode {
  '@type': 'SoftwareApplication';
  '@id': string;
  name: string;
  applicationCategory: string;
  applicationSubCategory: string;
  operatingSystem: string;
  description: string;
  url: string;
  downloadUrl: string;
  license: string;
  isAccessibleForFree: boolean;
  offers: JsonLdOffer;
  featureList: readonly string[];
  author: { '@id': string };
  publisher: { '@id': string };
}

export interface OrganizationNode {
  '@type': 'Organization';
  '@id': string;
  name: string;
  url: string;
  sameAs: readonly string[];
}

export interface FaqQuestionNode {
  '@type': 'Question';
  name: string;
  acceptedAnswer: { '@type': 'Answer'; text: string };
}

export interface FaqPageNode {
  '@type': 'FAQPage';
  '@id': string;
  mainEntity: FaqQuestionNode[];
}

export interface HowToStepNode {
  '@type': 'HowToStep';
  position: number;
  name: string;
  text: string;
}

export interface HowToNode {
  '@type': 'HowTo';
  '@id': string;
  name: string;
  description: string;
  step: readonly HowToStepNode[];
}

export interface WebPageNode {
  '@type': 'WebPage';
  '@id': string;
  name: string;
  description: string;
  isPartOf: { '@id': string };
  about: { '@id': string };
}

export interface BreadcrumbItemNode {
  '@type': 'ListItem';
  position: number;
  name: string;
  item: string;
}

export interface BreadcrumbListNode {
  '@type': 'BreadcrumbList';
  '@id': string;
  itemListElement: readonly BreadcrumbItemNode[];
}

export type JsonLdNode =
  | SoftwareApplicationNode
  | OrganizationNode
  | FaqPageNode
  | HowToNode
  | WebPageNode
  | BreadcrumbListNode;

export interface JsonLdGraph {
  '@context': 'https://schema.org';
  '@graph': JsonLdNode[];
}

// The FAQ input the FAQPage builder consumes — `answer` is the SAME Lexical
// value the page renders, guaranteeing schema text can't drift from visible
// copy (AC4 — see faq-plaintext.ts).
export interface FaqSchemaInput {
  question: string;
  answer: SerializedEditorState;
}

// Static nodes transcribed verbatim from docs/gtm/site-brief.md §3.
export const softwareApplicationNode: SoftwareApplicationNode = {
  '@type': 'SoftwareApplication',
  '@id': 'https://github.com/whimzyLive/nightshift-ai#software',
  name: 'nightshift',
  applicationCategory: 'DeveloperApplication',
  applicationSubCategory: 'Claude Code plugin',
  operatingSystem: 'Any (runs inside Claude Code)',
  description:
    'A free, MIT-licensed Claude Code plugin that turns one terminal into a full software-delivery team — product manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the spec, plan, code, and review automatically.',
  url: 'https://github.com/whimzyLive/nightshift-ai',
  downloadUrl: 'https://github.com/whimzyLive/nightshift-ai',
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
    'Hard gates at every phase that return control to the developer',
  ],
  author: { '@id': 'https://github.com/whimzyLive#org' },
  publisher: { '@id': 'https://github.com/whimzyLive#org' },
};

export const organizationNode: OrganizationNode = {
  '@type': 'Organization',
  '@id': 'https://github.com/whimzyLive#org',
  name: 'whimzyLive',
  url: 'https://github.com/whimzyLive',
  sameAs: ['https://github.com/whimzyLive/nightshift-ai'],
};

export const howToNode: HowToNode = {
  '@type': 'HowTo',
  '@id': 'https://github.com/whimzyLive/nightshift-ai#ship-while-you-sleep',
  name: 'How to ship software while you sleep with nightshift',
  description:
    'The day/night workflow: refine and approve stories during the day, let the plugin implement approved work overnight, and review the resulting PRs in the morning.',
  step: [
    {
      '@type': 'HowToStep',
      position: 1,
      name: 'Refine by day',
      text: 'Pre-refine every story with clear acceptance criteria and write a full spec for the complicated ones, using the refinement and spec commands.',
    },
    {
      '@type': 'HowToStep',
      position: 2,
      name: 'Review and approve',
      text: 'Review the refined stories and specs, decide what is ready, and approve them. You make the decisions; you do not write the implementation.',
    },
    {
      '@type': 'HowToStep',
      position: 3,
      name: 'Implement overnight',
      text: 'Run /auto on the approved tickets. It triages each one and routes it to the right approach, following the practices your domain agents enforce for that repo.',
    },
    {
      '@type': 'HowToStep',
      position: 4,
      name: 'Review the PRs in the morning',
      text: 'Wake up to PRs ready for review. Each one addresses acceptance criteria you already agreed to or a spec you already approved.',
    },
  ],
};

export const whySdlcWebPageNode: WebPageNode = {
  '@type': 'WebPage',
  '@id': 'https://github.com/whimzyLive/nightshift-ai/why-sdlc#webpage',
  name: 'Why an SDLC beats one-shot AI — nightshift',
  description:
    'Most AI dev tools abstract the process away. nightshift enforces the software development lifecycle instead, with a hard gate at every phase that keeps the developer in control.',
  isPartOf: { '@id': 'https://github.com/whimzyLive/nightshift-ai#software' },
  about: { '@id': 'https://github.com/whimzyLive/nightshift-ai#software' },
};

export const whySdlcBreadcrumbNode: BreadcrumbListNode = {
  '@type': 'BreadcrumbList',
  '@id': 'https://github.com/whimzyLive/nightshift-ai/why-sdlc#breadcrumb',
  itemListElement: [
    {
      '@type': 'ListItem',
      position: 1,
      name: 'Home',
      item: 'https://github.com/whimzyLive/nightshift-ai',
    },
    {
      '@type': 'ListItem',
      position: 2,
      name: 'Why SDLC',
      item: 'https://github.com/whimzyLive/nightshift-ai/why-sdlc',
    },
  ],
};

/**
 * Builds a FAQPage node from already-rendered FAQ data. Returns `null` when
 * `faqs` is empty — never emit a node with an empty `mainEntity` (Error
 * Handling: "do not emit a FAQPage node with an empty mainEntity array").
 */
export function buildFaqPageNode(
  id: string,
  faqs: FaqSchemaInput[],
): FaqPageNode | null {
  if (faqs.length === 0) return null;

  return {
    '@type': 'FAQPage',
    '@id': id,
    mainEntity: faqs.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faqAnswerToPlaintext(faq.answer),
      },
    })),
  };
}
