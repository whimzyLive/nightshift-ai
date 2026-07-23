import { validateSlug } from './Pages';

jest.mock('next/cache', () => ({ revalidatePath: jest.fn() }));

describe('validateSlug', () => {
  it('rejects a reserved slug case-insensitively', () => {
    expect(validateSlug('Home')).not.toBe(true);
    expect(validateSlug('FAQ')).not.toBe(true);
    expect(validateSlug('home')).not.toBe(true);
  });

  it('rejects a slug with spaces or slashes', () => {
    expect(validateSlug('foo/bar')).not.toBe(true);
    expect(validateSlug('my page')).not.toBe(true);
  });

  it('accepts a valid kebab-case slug', () => {
    expect(validateSlug('valid-slug')).toBe(true);
  });

  it('ignores non-string values', () => {
    expect(validateSlug(undefined)).toBe(true);
  });
});
