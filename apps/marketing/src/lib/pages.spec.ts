import { getPayload } from 'payload';

import { getPageBySlug, getPublishedPageSlugs } from './pages';

jest.mock('@payload-config', () => ({ default: {} }), { virtual: true });
jest.mock('payload', () => ({ getPayload: jest.fn() }));

const mockGetPayload = getPayload as jest.Mock;
const mockFind = jest.fn();

beforeEach(() => {
  mockFind.mockReset();
  mockGetPayload.mockReset().mockResolvedValue({ find: mockFind });
});

describe('getPageBySlug', () => {
  it('queries published pages by slug at depth 1', async () => {
    mockFind.mockResolvedValue({ docs: [{ title: 'About', content: [] }] });
    const page = await getPageBySlug('about');
    expect(mockFind).toHaveBeenCalledWith({
      collection: 'pages',
      where: {
        and: [
          { slug: { equals: 'about' } },
          { _status: { equals: 'published' } },
        ],
      },
      limit: 1,
      depth: 1,
    });
    expect(page).toEqual({ title: 'About', content: [] });
  });

  it('returns null when no page matches', async () => {
    mockFind.mockResolvedValue({ docs: [] });
    expect(await getPageBySlug('missing')).toBeNull();
  });

  it('propagates a thrown Payload/DB error (does not become null)', async () => {
    mockFind.mockRejectedValue(new Error('db down'));
    await expect(getPageBySlug('about')).rejects.toThrow('db down');
  });
});

describe('getPublishedPageSlugs', () => {
  it('projects published slugs only at depth 0', async () => {
    mockFind.mockResolvedValue({ docs: [{ slug: 'a' }, { slug: 'b' }] });
    const slugs = await getPublishedPageSlugs();
    expect(mockFind).toHaveBeenCalledWith({
      collection: 'pages',
      where: { _status: { equals: 'published' } },
      limit: 1000,
      depth: 0,
      select: { slug: true },
    });
    expect(slugs).toEqual([{ slug: 'a' }, { slug: 'b' }]);
  });

  it('returns [] (not throw) on a build-time DB failure', async () => {
    mockFind.mockRejectedValue(new Error('no db at build'));
    expect(await getPublishedPageSlugs()).toEqual([]);
  });
});
