import { DEPARTMENTS, YOU, PHILOSOPHY, HANDBOOK_STEPS } from './roster-data';

describe('roster-data', () => {
  it('has five departments in order excluding Leadership', () => {
    expect(DEPARTMENTS.map((d) => d.title)).toEqual([
      'Product',
      'Architecture & Planning',
      'Engineering',
      'Quality',
      'On contract',
    ]);
  });

  it('YOU card is the human with no charter file', () => {
    expect(YOU.tier).toBe('human');
    expect(YOU.file).toBeNull();
  });

  it('lists all 12 non-you members with the correct tiers', () => {
    const members = DEPARTMENTS.flatMap((d) => d.members);
    expect(members).toHaveLength(12);
    const opus = members
      .filter((m) => m.tier === 'opus')
      .map((m) => m.name)
      .sort();
    expect(opus).toEqual(
      [
        'principal-engineer',
        'product-manager',
        'qa-engineer',
        'solutions-architect',
        'tech-lead',
      ].sort(),
    );
    expect(members.filter((m) => m.tier === 'sonnet')).toHaveLength(7);
  });

  it('every member charter file is a non-empty .md name', () => {
    for (const m of DEPARTMENTS.flatMap((d) => d.members)) {
      expect(m.file).toMatch(/^[a-z-]+\.md$/);
    }
  });

  it('principal-engineer and qa-engineer override fileUrl to the surviving playbook refs', () => {
    const members = DEPARTMENTS.flatMap((d) => d.members);
    const pe = members.find((m) => m.name === 'principal-engineer');
    const qe = members.find((m) => m.name === 'qa-engineer');
    expect(pe?.fileUrl).toBe(
      'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/refs/principal-engineer-playbook.md',
    );
    expect(qe?.fileUrl).toBe(
      'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/refs/qa-engineer-playbook.md',
    );
  });

  it('every other member has no fileUrl override', () => {
    const members = DEPARTMENTS.flatMap((d) => d.members);
    for (const m of members) {
      if (m.name === 'principal-engineer' || m.name === 'qa-engineer') continue;
      expect(m.fileUrl).toBeUndefined();
    }
  });

  it('renders 4 philosophy cards and 6 handbook steps', () => {
    expect(PHILOSOPHY).toHaveLength(4);
    expect(HANDBOOK_STEPS).toHaveLength(6);
    expect(HANDBOOK_STEPS[2]).toContain('.claude/project/agents/<you>.md');
  });
});
