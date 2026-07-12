import { getPayload } from 'payload';

import { getHomeFaqs } from './faq';

import type { Faq } from '../payload-types';

// '@payload-config' is a tsconfig path alias (./src/payload.config.ts), not a
// real package — next/jest's automatic moduleNameMapper wiring doesn't cover
// it, so `{ virtual: true }` is required (see NA-16 memory).
jest.mock('@payload-config', () => ({ default: {} }), { virtual: true });
// Factory references nothing from module scope (avoids the hoisting TDZ
// documented in the NA-16/NA-30 memory) — the mock is retrieved back via
// `getPayload as jest.Mock` below instead of a `mock`-prefixed closure var.
jest.mock('payload', () => ({ getPayload: jest.fn() }));

const mockGetPayload = getPayload as jest.Mock;
const mockFind = jest.fn();

function makeFaqDoc(overrides: Partial<Faq>): Faq {
  return {
    id: 1,
    seedKey: 'seed-key',
    question: 'A question?',
    group: 'positioning',
    answer: {
      root: {
        type: 'root',
        children: [],
        direction: 'ltr',
        format: '',
        indent: 0,
        version: 1,
      },
    },
    faqOrder: 1,
    showOnHome: true,
    showOnWhySdlc: false,
    updatedAt: '2026-01-01',
    createdAt: '2026-01-01',
    ...overrides,
  };
}

describe('getHomeFaqs', () => {
  beforeEach(() => {
    mockFind.mockReset();
    mockGetPayload.mockReset().mockResolvedValue({ find: mockFind });
  });

  it('queries the faq collection for showOnHome docs, sorted by homeOrder, limited to 5', async () => {
    mockFind.mockResolvedValue({ docs: [] });
    await getHomeFaqs();
    expect(mockFind).toHaveBeenCalledWith({
      collection: 'faq',
      where: { showOnHome: { equals: true } },
      sort: 'homeOrder',
      limit: 5,
      depth: 0,
    });
  });

  it('prefers homeAnswer over answer when present', async () => {
    const homeAnswer = {
      root: {
        type: 'root',
        children: [{ type: 'paragraph', version: 1 }],
        direction: 'ltr' as const,
        format: '' as const,
        indent: 0,
        version: 1,
      },
    };
    mockFind.mockResolvedValue({
      docs: [makeFaqDoc({ id: 2, question: 'Q2', homeAnswer })],
    });
    const result = await getHomeFaqs();
    expect(result).toEqual([{ id: 2, question: 'Q2', answer: homeAnswer }]);
  });

  it('falls back to answer when homeAnswer is absent', async () => {
    const answer = makeFaqDoc({}).answer;
    mockFind.mockResolvedValue({
      docs: [makeFaqDoc({ id: 3, question: 'Q3', answer })],
    });
    const result = await getHomeFaqs();
    expect(result).toEqual([{ id: 3, question: 'Q3', answer }]);
  });

  it('returns an empty array when the Payload call fails, instead of throwing', async () => {
    mockFind.mockRejectedValue(new Error('db unreachable'));
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    await expect(getHomeFaqs()).resolves.toEqual([]);
    expect(consoleErrorSpy).toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });
});
