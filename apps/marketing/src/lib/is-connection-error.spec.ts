import { isConnectionOrInitError } from './is-connection-error';

function withCode(code: string, message = code): Error {
  return Object.assign(new Error(message), { code });
}

describe('isConnectionOrInitError', () => {
  it('returns true for ECONNREFUSED', () => {
    expect(isConnectionOrInitError(withCode('ECONNREFUSED'))).toBe(true);
  });

  it('returns true for ENOTFOUND', () => {
    expect(isConnectionOrInitError(withCode('ENOTFOUND'))).toBe(true);
  });

  it('returns true for the transient network codes ETIMEDOUT/ECONNRESET/EPIPE/EHOSTUNREACH/ENETUNREACH/EAI_AGAIN', () => {
    for (const code of [
      'ETIMEDOUT',
      'ECONNRESET',
      'EPIPE',
      'EHOSTUNREACH',
      'ENETUNREACH',
      'EAI_AGAIN',
    ]) {
      expect(isConnectionOrInitError(withCode(code))).toBe(true);
    }
  });

  it('returns true for an unmigrated-schema SQLSTATE (42P01 undefined_table)', () => {
    expect(isConnectionOrInitError(withCode('42P01'))).toBe(true);
  });

  it('returns true for an unmigrated-schema SQLSTATE (3F000 invalid_schema_name)', () => {
    expect(isConnectionOrInitError(withCode('3F000'))).toBe(true);
  });

  it('returns true for connection-class SQLSTATE (08*)', () => {
    expect(isConnectionOrInitError(withCode('08006'))).toBe(true);
  });

  it('returns true for auth-class SQLSTATE (28*)', () => {
    expect(isConnectionOrInitError(withCode('28000'))).toBe(true);
  });

  it('returns true for operator-intervention SQLSTATE (57P01 admin_shutdown, 57P03 cannot_connect_now)', () => {
    expect(isConnectionOrInitError(withCode('57P01'))).toBe(true);
    expect(isConnectionOrInitError(withCode('57P03'))).toBe(true);
  });

  it('returns true for insufficient-resources SQLSTATE (53300 too_many_connections)', () => {
    expect(isConnectionOrInitError(withCode('53300'))).toBe(true);
  });

  it('does NOT broaden to the whole 42 class — a row/column-shape defect (42703 undefined_column) still returns false', () => {
    expect(isConnectionOrInitError(withCode('42703'))).toBe(false);
  });

  it('returns false for a plain business-logic error with no code', () => {
    expect(isConnectionOrInitError(new Error('bad row'))).toBe(false);
  });

  it('returns false for a TypeError data-shape defect', () => {
    expect(
      isConnectionOrInitError(new TypeError("Cannot read 'x' of null")),
    ).toBe(false);
  });

  it('walks error.cause to find a wrapped connection code', () => {
    const wrapped = new Error('Payload init failed', {
      cause: withCode('ECONNRESET'),
    });
    expect(isConnectionOrInitError(wrapped)).toBe(true);
  });

  it('walks a multi-level cause chain', () => {
    const innermost = withCode('57P03');
    const middle = new Error('driver error', { cause: innermost });
    const outer = new Error('payload wrapper', { cause: middle });
    expect(isConnectionOrInitError(outer)).toBe(true);
  });

  it('does not walk past a depth guard on a pathological cause cycle', () => {
    const a: { message: string; cause?: unknown } = { message: 'a' };
    const b: { message: string; cause?: unknown } = { message: 'b', cause: a };
    a.cause = b;
    expect(() => isConnectionOrInitError(a)).not.toThrow();
    expect(isConnectionOrInitError(a)).toBe(false);
  });

  it('inspects a non-Error object for a code (e.g. a serialized/aggregate error)', () => {
    expect(isConnectionOrInitError({ code: 'ECONNREFUSED' })).toBe(true);
  });

  it('returns false for a non-Error object with no code', () => {
    expect(isConnectionOrInitError({ message: 'nope' })).toBe(false);
  });

  it('returns false for null/undefined', () => {
    expect(isConnectionOrInitError(null)).toBe(false);
    expect(isConnectionOrInitError(undefined)).toBe(false);
  });
});
