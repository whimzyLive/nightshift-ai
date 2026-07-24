import { withDbFallback } from './with-db-fallback';

function withCode(code: string): Error {
  return Object.assign(new Error(code), { code });
}

describe('withDbFallback', () => {
  it('returns the operation result on success', async () => {
    const result = await withDbFallback('[test]', [], async () => ['ok']);
    expect(result).toEqual(['ok']);
  });

  it('logs and returns the fallback on a row-level/data-shape defect', async () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    const result = await withDbFallback('[test]', [], async () => {
      throw new TypeError("Cannot read 'x' of null");
    });
    expect(result).toEqual([]);
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      '[test]',
      expect.any(TypeError),
    );
    consoleErrorSpy.mockRestore();
  });

  it('rethrows a connection/init-class error without logging as swallowed', async () => {
    await expect(
      withDbFallback('[test]', [], async () => {
        throw withCode('ECONNREFUSED');
      }),
    ).rejects.toThrow(/ECONNREFUSED/);
  });

  it('does not throw on a legitimately empty result', async () => {
    const result = await withDbFallback('[test]', [], async () => []);
    expect(result).toEqual([]);
  });
});
