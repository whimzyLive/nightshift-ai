import { getPayload } from 'payload';

import { getFaqPageGroups, getHomeFaqs } from './faq';

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

  it('returns an empty array when the Payload call fails with a row-level defect, instead of throwing', async () => {
    mockFind.mockRejectedValue(new TypeError("Cannot read 'answer' of null"));
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    await expect(getHomeFaqs()).resolves.toEqual([]);
    expect(consoleErrorSpy).toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });

  it('rethrows when getPayload fails to initialise (connection/init class)', async () => {
    mockGetPayload.mockReset().mockRejectedValueOnce(
      Object.assign(new Error('connect ECONNREFUSED'), {
        code: 'ECONNREFUSED',
      }),
    );
    await expect(getHomeFaqs()).rejects.toThrow(/ECONNREFUSED/);
  });

  it('rethrows when the query rejects with a connection-class error', async () => {
    mockFind.mockRejectedValue(
      Object.assign(new Error('timeout'), { code: 'ETIMEDOUT' }),
    );
    await expect(getHomeFaqs()).rejects.toThrow(/timeout/);
  });

  it('swallows a row-level/data-shape defect and returns []', async () => {
    mockFind.mockRejectedValue(new TypeError("Cannot read 'answer' of null"));
    await expect(getHomeFaqs()).resolves.toEqual([]);
  });

  it('returns [] for a legitimately empty result set (not an error)', async () => {
    mockFind.mockResolvedValue({ docs: [] });
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    await expect(getHomeFaqs()).resolves.toEqual([]);
    expect(consoleErrorSpy).not.toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });
});

describe('getFaqPageGroups', () => {
  beforeEach(() => {
    mockFind.mockReset();
    mockGetPayload.mockReset().mockResolvedValue({ find: mockFind });
  });

  it('queries all faq docs sorted by faqOrder (no where filter, limit 100, depth 0)', async () => {
    mockFind.mockResolvedValue({ docs: [] });
    await getFaqPageGroups();
    expect(mockFind).toHaveBeenCalledWith({
      collection: 'faq',
      sort: 'faqOrder',
      limit: 100,
      depth: 0,
    });
  });

  it('partitions into groups in first-appearance order with mapped eyebrow labels', async () => {
    mockFind.mockResolvedValue({
      docs: [
        makeFaqDoc({
          id: 1,
          group: 'positioning',
          faqOrder: 1,
          question: 'Q1',
        }),
        makeFaqDoc({
          id: 2,
          group: 'positioning',
          faqOrder: 2,
          question: 'Q2',
        }),
        makeFaqDoc({
          id: 3,
          group: 'workflow-control',
          faqOrder: 3,
          question: 'Q3',
        }),
      ],
    });
    const groups = await getFaqPageGroups();
    expect(groups.map((g) => g.key)).toEqual([
      'positioning',
      'workflow-control',
    ]);
    expect(groups[0].eyebrow).toBe('// positioning');
    expect(groups[1].eyebrow).toBe('// workflow & control');
  });

  it('sets item.number equal to faqOrder (continuous across group boundaries)', async () => {
    mockFind.mockResolvedValue({
      docs: [
        makeFaqDoc({ id: 1, group: 'positioning', faqOrder: 1 }),
        makeFaqDoc({ id: 3, group: 'workflow-control', faqOrder: 3 }),
      ],
    });
    const groups = await getFaqPageGroups();
    expect(groups[0].items[0].number).toBe(1);
    expect(groups[1].items[0].number).toBe(3);
  });

  it('uses the full answer field, not homeAnswer', async () => {
    const answer = makeFaqDoc({}).answer;
    mockFind.mockResolvedValue({
      docs: [
        makeFaqDoc({
          id: 1,
          group: 'positioning',
          faqOrder: 1,
          answer,
          homeAnswer: null,
        }),
      ],
    });
    const groups = await getFaqPageGroups();
    expect(groups[0].items[0].answer).toBe(answer);
  });

  it('returns [] on a row-level/data-shape defect', async () => {
    mockFind.mockRejectedValue(new TypeError('bad row'));
    await expect(getFaqPageGroups()).resolves.toEqual([]);
  });

  it('rethrows when getPayload fails to initialise (connection/init class)', async () => {
    mockGetPayload.mockReset().mockRejectedValueOnce(
      Object.assign(new Error('connect ECONNREFUSED'), {
        code: 'ECONNREFUSED',
      }),
    );
    await expect(getFaqPageGroups()).rejects.toThrow(/ECONNREFUSED/);
  });

  it('rethrows when the query rejects with a connection-class error', async () => {
    mockFind.mockRejectedValue(
      Object.assign(new Error('auth failed'), { code: '28000' }),
    );
    await expect(getFaqPageGroups()).rejects.toThrow(/auth failed/);
  });

  it('returns [] for a legitimately empty result set (not an error)', async () => {
    mockFind.mockResolvedValue({ docs: [] });
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    await expect(getFaqPageGroups()).resolves.toEqual([]);
    expect(consoleErrorSpy).not.toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });
});
