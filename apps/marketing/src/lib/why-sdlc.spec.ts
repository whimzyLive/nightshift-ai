import { getPayload } from 'payload';

import { getWhySdlcContent, getWhySdlcFaqs } from './why-sdlc';

import type { Faq, WhySdlc } from '../payload-types';

// '@payload-config' is a tsconfig path alias (./src/payload.config.ts), not a
// real package — next/jest's automatic moduleNameMapper wiring doesn't cover
// it, so `{ virtual: true }` is required (see NA-16 memory).
jest.mock('@payload-config', () => ({ default: {} }), { virtual: true });
// Factory references nothing from module scope (avoids the hoisting TDZ
// documented in the NA-16/NA-30 memory) — the mock is retrieved back via
// `getPayload as jest.Mock` below instead of a `mock`-prefixed closure var.
jest.mock('payload', () => ({ getPayload: jest.fn() }));

const mockGetPayload = getPayload as jest.Mock;
const mockFindGlobal = jest.fn();
const mockFind = jest.fn();

function richText(text: string) {
  return {
    root: {
      type: 'root',
      children: [
        {
          type: 'paragraph',
          version: 1,
          children: [{ type: 'text', version: 1, text, format: 0 }],
        },
      ],
      direction: 'ltr' as const,
      format: '' as const,
      indent: 0,
      version: 1,
    },
  };
}

function makeWhySdlcGlobal(overrides: Partial<WhySdlc> = {}): WhySdlc {
  return {
    id: 1,
    intro: {
      eyebrow: '// why an sdlc',
      heading: 'You decide how it gets built',
      lead: richText('Frameworks keep promising to do everything for you.'),
      scrollHint: 'five sections · five gates',
    },
    arguments: [
      {
        eyebrow: '// 01 · the trend',
        heading: 'Abstraction that takes the wheel',
        body: richText('body 1'),
      },
      {
        eyebrow: '// 02 · the answer',
        heading: 'The lifecycle you already trust',
        body: richText('body 2'),
      },
      {
        eyebrow: '// 03 · hard gates',
        heading: 'Hard gates return control',
        body: richText('body 3'),
      },
      {
        eyebrow: '// 04 · no one-shot',
        heading: 'No building it all in one shot',
        body: richText('body 4'),
      },
      {
        eyebrow: '// 05 · builds like you',
        heading: 'It builds the way you would',
        body: richText('body 5'),
      },
    ],
    updatedAt: '2026-01-01',
    createdAt: '2026-01-01',
    ...overrides,
  };
}

function makeFaqDoc(overrides: Partial<Faq>): Faq {
  return {
    id: 1,
    seedKey: 'seed-key',
    question: 'A question?',
    group: 'positioning',
    answer: richText('answer'),
    faqOrder: 1,
    showOnHome: false,
    showOnWhySdlc: true,
    updatedAt: '2026-01-01',
    createdAt: '2026-01-01',
    ...overrides,
  };
}

describe('getWhySdlcContent', () => {
  beforeEach(() => {
    mockFindGlobal.mockReset();
    mockGetPayload
      .mockReset()
      .mockResolvedValue({ findGlobal: mockFindGlobal });
  });

  it('calls findGlobal for the whySdlc slug and returns intro + arguments', async () => {
    mockFindGlobal.mockResolvedValue(makeWhySdlcGlobal());
    const result = await getWhySdlcContent();
    expect(mockFindGlobal).toHaveBeenCalledWith({ slug: 'whySdlc', depth: 0 });
    expect(result).not.toBeNull();
    expect(result?.arguments).toHaveLength(5);
    expect(result?.intro.heading).toBe('You decide how it gets built');
  });

  it('returns null (and logs) on a row-level/data-shape defect', async () => {
    mockFindGlobal.mockRejectedValue(new TypeError('bad global shape'));
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    await expect(getWhySdlcContent()).resolves.toBeNull();
    expect(consoleErrorSpy).toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });

  it('rethrows when getPayload fails to initialise (connection/init class)', async () => {
    mockGetPayload.mockReset().mockRejectedValueOnce(
      Object.assign(new Error('connect ECONNREFUSED'), {
        code: 'ECONNREFUSED',
      }),
    );
    await expect(getWhySdlcContent()).rejects.toThrow(/ECONNREFUSED/);
  });

  it('rethrows when findGlobal rejects with a connection-class error', async () => {
    mockFindGlobal.mockRejectedValue(
      Object.assign(new Error('connection refused'), {
        code: 'ECONNREFUSED',
      }),
    );
    await expect(getWhySdlcContent()).rejects.toThrow(/connection refused/);
  });

  it('rethrows on a transient DNS failure (EAI_AGAIN)', async () => {
    mockFindGlobal.mockRejectedValue(
      Object.assign(new Error('getaddrinfo EAI_AGAIN'), {
        code: 'EAI_AGAIN',
      }),
    );
    await expect(getWhySdlcContent()).rejects.toThrow(/EAI_AGAIN/);
  });

  it('rethrows when a wrapped driver error carries the connection code via error.cause', async () => {
    mockFindGlobal.mockRejectedValue(
      new Error('Payload query failed', {
        cause: Object.assign(new Error('socket hang up'), {
          code: 'ECONNRESET',
        }),
      }),
    );
    await expect(getWhySdlcContent()).rejects.toThrow(/Payload query failed/);
  });

  it('returns null for a legitimately empty/absent global (not an error)', async () => {
    mockFindGlobal.mockResolvedValue(makeWhySdlcGlobal({ arguments: [] }));
    const result = await getWhySdlcContent();
    expect(result?.arguments).toEqual([]);
  });
});

describe('getWhySdlcFaqs', () => {
  beforeEach(() => {
    mockFind.mockReset();
    mockGetPayload.mockReset().mockResolvedValue({ find: mockFind });
  });

  it('queries the faq collection for showOnWhySdlc docs, sorted by whySdlcOrder, limited to 2', async () => {
    mockFind.mockResolvedValue({ docs: [] });
    await getWhySdlcFaqs();
    expect(mockFind).toHaveBeenCalledWith({
      collection: 'faq',
      where: { showOnWhySdlc: { equals: true } },
      sort: 'whySdlcOrder',
      limit: 2,
      depth: 0,
    });
  });

  it('prefers whySdlcAnswer over answer when present', async () => {
    const whySdlcAnswer = richText('the why-sdlc answer');
    mockFind.mockResolvedValue({
      docs: [makeFaqDoc({ id: 2, question: 'Q2', whySdlcAnswer })],
    });
    const result = await getWhySdlcFaqs();
    expect(result).toEqual([{ id: 2, question: 'Q2', answer: whySdlcAnswer }]);
  });

  it('falls back to answer when whySdlcAnswer is absent', async () => {
    const answer = richText('the plain answer');
    mockFind.mockResolvedValue({
      docs: [makeFaqDoc({ id: 3, question: 'Q3', answer })],
    });
    const result = await getWhySdlcFaqs();
    expect(result).toEqual([{ id: 3, question: 'Q3', answer }]);
  });

  it('returns an empty array on a row-level/data-shape defect, instead of throwing', async () => {
    mockFind.mockRejectedValue(new TypeError("Cannot read 'answer' of null"));
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    await expect(getWhySdlcFaqs()).resolves.toEqual([]);
    expect(consoleErrorSpy).toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });

  it('rethrows when getPayload fails to initialise (connection/init class)', async () => {
    mockGetPayload.mockReset().mockRejectedValueOnce(
      Object.assign(new Error('connect ECONNREFUSED'), {
        code: 'ECONNREFUSED',
      }),
    );
    await expect(getWhySdlcFaqs()).rejects.toThrow(/ECONNREFUSED/);
  });

  it('rethrows when the query rejects with a connection-class error', async () => {
    mockFind.mockRejectedValue(
      Object.assign(new Error('host not found'), { code: 'ENOTFOUND' }),
    );
    await expect(getWhySdlcFaqs()).rejects.toThrow(/host not found/);
  });

  it('rethrows on an operator-intervention SQLSTATE (57P03 cannot_connect_now)', async () => {
    mockFind.mockRejectedValue(
      Object.assign(new Error('the database system is starting up'), {
        code: '57P03',
      }),
    );
    await expect(getWhySdlcFaqs()).rejects.toThrow(/starting up/);
  });

  it('rethrows a non-Error thrown value that carries a connection code', async () => {
    mockFind.mockRejectedValue({ code: 'ECONNREFUSED' });
    await expect(getWhySdlcFaqs()).rejects.toEqual({ code: 'ECONNREFUSED' });
  });

  it('returns [] for a legitimately empty result set (not an error)', async () => {
    mockFind.mockResolvedValue({ docs: [] });
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    await expect(getWhySdlcFaqs()).resolves.toEqual([]);
    expect(consoleErrorSpy).not.toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });
});
