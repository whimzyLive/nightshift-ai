import type { CollectionConfig, NumberFieldSingleValidation } from 'payload';

/** Field-level validate factory for an order field that's required-by-convention once its surface flag is on. */
const requiredWhenFlagged = (
  flagField: 'showOnHome' | 'showOnWhySdlc',
): NumberFieldSingleValidation => {
  return (value, { siblingData }) => {
    const data = siblingData as Record<string, unknown>;
    if (data[flagField] && (value === null || value === undefined)) {
      return `Required when ${flagField} is enabled.`;
    }
    return true;
  };
};

export const Faq: CollectionConfig = {
  slug: 'faq',
  admin: {
    useAsTitle: 'question',
    group: 'Content',
    defaultColumns: [
      'question',
      'group',
      'faqOrder',
      'showOnHome',
      'showOnWhySdlc',
    ],
  },
  access: {
    read: () => true,
    create: ({ req: { user } }) => Boolean(user),
    update: ({ req: { user } }) => Boolean(user),
    delete: ({ req: { user } }) => Boolean(user),
  },
  fields: [
    {
      name: 'seedKey',
      type: 'text',
      required: true,
      unique: true,
      admin: {
        readOnly: true,
      },
    },
    {
      name: 'question',
      type: 'text',
      required: true,
    },
    {
      name: 'group',
      type: 'select',
      required: true,
      options: [
        { label: '// positioning', value: 'positioning' },
        { label: '// workflow & control', value: 'workflow-control' },
        { label: '// setup & stack', value: 'setup-stack' },
        { label: '// trust & quality', value: 'trust-quality' },
        { label: '// cost & license', value: 'cost-license' },
      ],
    },
    {
      name: 'answer',
      type: 'richText',
      required: true,
    },
    {
      name: 'faqOrder',
      type: 'number',
      required: true,
    },
    {
      name: 'showOnHome',
      type: 'checkbox',
      required: true,
      defaultValue: false,
    },
    {
      name: 'homeOrder',
      type: 'number',
      validate: requiredWhenFlagged('showOnHome'),
    },
    {
      name: 'homeAnswer',
      type: 'richText',
    },
    {
      name: 'showOnWhySdlc',
      type: 'checkbox',
      required: true,
      defaultValue: false,
    },
    {
      name: 'whySdlcOrder',
      type: 'number',
      validate: requiredWhenFlagged('showOnWhySdlc'),
    },
    {
      name: 'whySdlcAnswer',
      type: 'richText',
    },
  ],
};
