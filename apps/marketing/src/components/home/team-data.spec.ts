import { agents, ORG_LEVELS } from './team-data';

describe('team-data', () => {
  it('has exactly 11 roster agents', () => {
    expect(agents).toHaveLength(11);
  });

  it('marks only mobile-engineer and sync-engineer as standby', () => {
    const standbyNames = agents.filter((a) => a.standby).map((a) => a.name);
    expect(standbyNames.sort()).toEqual(['mobile-engineer', 'sync-engineer']);
  });

  it('covers org levels L0 through L6 in order', () => {
    expect(ORG_LEVELS.map((l) => l.num)).toEqual([
      'L0',
      'L1',
      'L2',
      'L3',
      'L4',
      'L5',
      'L6',
    ]);
  });

  it('nests the L5 domain agents under principal-engineer with sequence notes', () => {
    const l5 = ORG_LEVELS.find((l) => l.num === 'L5');
    expect(l5?.agentNames).toEqual([
      'principal-engineer',
      'database-administrator',
      'platform-engineer',
      'sync-engineer',
      'web-engineer',
      'mobile-engineer',
    ]);
    expect(l5?.seqs).toMatchObject({
      'principal-engineer': 'orchestrates',
      'database-administrator': 'phase 1',
      'platform-engineer': 'phase 2',
      'sync-engineer': 'phase 3',
      'web-engineer': 'phase 4',
      'mobile-engineer': 'phase 5',
    });
  });
});
