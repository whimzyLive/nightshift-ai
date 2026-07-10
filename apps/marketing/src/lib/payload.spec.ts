// jest.resetModules() + require() per test isolates the module-scoped `cached`
// variable — a static top-level import would share `cached` across tests.
describe('getPayloadClient', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  it('clears the cached promise on rejection so a subsequent call retries', async () => {
    jest.doMock('../payload.config', () => ({ default: {} }), {
      virtual: true,
    });
    const error = new Error('neon connection reset');
    const getPayload = jest
      .fn()
      .mockRejectedValueOnce(error)
      .mockResolvedValueOnce({ id: 'ok' });
    jest.doMock('payload', () => ({ getPayload }));

    const { getPayloadClient } = require('./payload');

    await expect(getPayloadClient()).rejects.toBe(error);
    const second = await getPayloadClient();

    expect(second).toEqual({ id: 'ok' });
    expect(getPayload).toHaveBeenCalledTimes(2);
  });

  it('memoizes the resolved client across calls on success', async () => {
    jest.doMock('../payload.config', () => ({ default: {} }), {
      virtual: true,
    });
    const instance = { id: 'ok' };
    const getPayload = jest.fn().mockResolvedValue(instance);
    jest.doMock('payload', () => ({ getPayload }));

    const { getPayloadClient } = require('./payload');

    const first = await getPayloadClient();
    const second = await getPayloadClient();

    expect(first).toBe(second);
    expect(getPayload).toHaveBeenCalledTimes(1);
  });
});
