import { revalidatePath } from 'next/cache';

import {
  revalidatePage,
  revalidatePageOnDelete,
  slugToPath,
} from './revalidatePage';

jest.mock('next/cache', () => ({ revalidatePath: jest.fn() }));

const mockRevalidatePath = revalidatePath as jest.Mock;

// Minimal shape the hook reads — cast to the hook arg to avoid rebuilding the full Payload type.
const call = (args: {
  doc: { slug: string };
  previousDoc?: { slug: string };
}) => (revalidatePage as unknown as (a: typeof args) => unknown)(args);

const callDelete = (args: { doc: { slug: string } | null }) =>
  (revalidatePageOnDelete as unknown as (a: typeof args) => unknown)(args);

describe('slugToPath', () => {
  it('maps a slug to its served path (no home special-case)', () => {
    expect(slugToPath('about')).toBe('/about');
    expect(slugToPath('home')).toBe('/home');
  });
});

describe('revalidatePage', () => {
  beforeEach(() => mockRevalidatePath.mockReset());

  it('revalidates the current doc path on save', () => {
    call({ doc: { slug: 'about' } });
    expect(mockRevalidatePath).toHaveBeenCalledWith('/about');
    expect(mockRevalidatePath).toHaveBeenCalledTimes(1);
  });

  it('also revalidates the previous path when the slug changed', () => {
    call({ doc: { slug: 'new' }, previousDoc: { slug: 'old' } });
    expect(mockRevalidatePath).toHaveBeenCalledWith('/new');
    expect(mockRevalidatePath).toHaveBeenCalledWith('/old');
    expect(mockRevalidatePath).toHaveBeenCalledTimes(2);
  });

  it('does not double-revalidate when the slug is unchanged', () => {
    call({ doc: { slug: 'same' }, previousDoc: { slug: 'same' } });
    expect(mockRevalidatePath).toHaveBeenCalledTimes(1);
  });

  it('swallows a revalidatePath throw and still returns doc', () => {
    mockRevalidatePath.mockImplementation(() => {
      throw new Error('boom');
    });
    const doc = { slug: 'x' };
    expect(call({ doc })).toBe(doc);
  });
});

describe('revalidatePageOnDelete', () => {
  beforeEach(() => mockRevalidatePath.mockReset());

  it('revalidates the deleted doc path', () => {
    const doc = { slug: 'about' };
    expect(callDelete({ doc })).toBe(doc);
    expect(mockRevalidatePath).toHaveBeenCalledWith('/about');
    expect(mockRevalidatePath).toHaveBeenCalledTimes(1);
  });

  it('swallows a revalidatePath throw and still returns doc', () => {
    mockRevalidatePath.mockImplementation(() => {
      throw new Error('boom');
    });
    const doc = { slug: 'x' };
    expect(callDelete({ doc })).toBe(doc);
  });
});
