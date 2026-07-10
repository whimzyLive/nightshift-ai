import type { GlobalConfig } from 'payload';

import { HOME_SLUG } from './slugs';

export const Home: GlobalConfig = {
  slug: HOME_SLUG,
  access: { read: () => true },
  fields: [
    {
      name: 'hero',
      type: 'group',
      fields: [
        { name: 'headline', type: 'text' },
        { name: 'subheadline', type: 'textarea' },
        { name: 'installCtaLabel', type: 'text' },
        { name: 'starCtaLabel', type: 'text' },
      ],
    },
    {
      name: 'proofBar',
      type: 'group',
      fields: [
        {
          name: 'items',
          type: 'array',
          fields: [
            { name: 'value', type: 'text' },
            { name: 'label', type: 'text' },
          ],
        },
      ],
    },
    {
      name: 'problem',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        { name: 'body', type: 'textarea' },
        {
          name: 'points',
          type: 'array',
          fields: [
            { name: 'lead', type: 'text' },
            { name: 'body', type: 'text' },
          ],
        },
      ],
    },
    {
      name: 'howItWorks',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        {
          name: 'steps',
          type: 'array',
          fields: [
            { name: 'title', type: 'text' },
            { name: 'body', type: 'text' },
          ],
        },
        { name: 'autoRunCaption', type: 'text' },
      ],
    },
    {
      name: 'workflow',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        {
          name: 'blocks',
          type: 'array',
          fields: [
            { name: 'label', type: 'text' },
            { name: 'body', type: 'textarea' },
          ],
        },
      ],
    },
    {
      name: 'team',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        { name: 'intro', type: 'text' },
        {
          name: 'agents',
          type: 'array',
          fields: [
            { name: 'name', type: 'text' },
            { name: 'role', type: 'text' },
          ],
        },
      ],
    },
    {
      name: 'whyDifferent',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        {
          name: 'cards',
          type: 'array',
          fields: [
            { name: 'heading', type: 'text' },
            { name: 'body', type: 'text' },
          ],
        },
      ],
    },
    {
      name: 'control',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        { name: 'body', type: 'textarea' },
        { name: 'linkLabel', type: 'text' },
        { name: 'linkHref', type: 'text' },
      ],
    },
    {
      name: 'faq',
      type: 'group',
      fields: [
        { name: 'eyebrow', type: 'text' },
        {
          name: 'items',
          type: 'array',
          fields: [
            { name: 'question', type: 'text' },
            { name: 'answer', type: 'richText' },
          ],
        },
      ],
    },
    {
      name: 'finalCta',
      type: 'group',
      fields: [
        { name: 'heading', type: 'text' },
        { name: 'body', type: 'text' },
      ],
    },
  ],
};
