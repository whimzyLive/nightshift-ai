import {
  __resetDbConfigWarningForTests,
  isDbConfigured,
  warnDbNotConfiguredOnce,
} from './db-config';

describe('isDbConfigured', () => {
  const originalDatabaseUrl = process.env.DATABASE_URL;

  afterEach(() => {
    if (originalDatabaseUrl === undefined) {
      delete process.env.DATABASE_URL;
    } else {
      process.env.DATABASE_URL = originalDatabaseUrl;
    }
  });

  it('returns false when DATABASE_URL is unset', () => {
    delete process.env.DATABASE_URL;
    expect(isDbConfigured()).toBe(false);
  });

  it('returns false when DATABASE_URL is an empty string', () => {
    process.env.DATABASE_URL = '';
    expect(isDbConfigured()).toBe(false);
  });

  it('returns false when DATABASE_URL is whitespace-only', () => {
    process.env.DATABASE_URL = '   ';
    expect(isDbConfigured()).toBe(false);
  });

  it('returns true when DATABASE_URL is set to a real connection string', () => {
    process.env.DATABASE_URL = 'postgres://user:pass@host:5432/db';
    expect(isDbConfigured()).toBe(true);
  });
});

describe('warnDbNotConfiguredOnce', () => {
  beforeEach(() => {
    __resetDbConfigWarningForTests();
  });

  it('logs the warning on the first call', () => {
    const consoleWarnSpy = jest.spyOn(console, 'warn').mockImplementation();
    warnDbNotConfiguredOnce();
    expect(consoleWarnSpy).toHaveBeenCalledTimes(1);
    expect(consoleWarnSpy).toHaveBeenCalledWith(
      expect.stringContaining('DATABASE_URL not set'),
    );
    consoleWarnSpy.mockRestore();
  });

  it('does not log again on subsequent calls (warn-once dedupe)', () => {
    const consoleWarnSpy = jest.spyOn(console, 'warn').mockImplementation();
    warnDbNotConfiguredOnce();
    warnDbNotConfiguredOnce();
    warnDbNotConfiguredOnce();
    expect(consoleWarnSpy).toHaveBeenCalledTimes(1);
    consoleWarnSpy.mockRestore();
  });
});
