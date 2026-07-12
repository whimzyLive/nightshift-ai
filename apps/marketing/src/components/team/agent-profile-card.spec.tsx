import { render, screen } from '@testing-library/react';

import { AgentProfileCard } from './agent-profile-card';
import type { AgentProfile } from './roster-data';

const sa: AgentProfile = {
  ini: 'SA',
  name: 'solutions-architect',
  title: 'Solutions Architect',
  tier: 'opus',
  owns: 'the technical spec',
  flow: 'after: scrum-master · hands to: tech-lead',
  artifact: 'docs/superpowers/specs/<KEY>.md',
  fact: 'never writes a line of app code',
  file: 'solutions-architect.md',
};

describe('AgentProfileCard', () => {
  it('renders initials, name, title, tier badge, owns, artifact and fact', () => {
    render(<AgentProfileCard agent={sa} />);
    expect(screen.getByText('SA')).toBeTruthy();
    expect(screen.getByText('solutions-architect')).toBeTruthy();
    expect(screen.getByText('Solutions Architect')).toBeTruthy();
    expect(screen.getByText('OPUS')).toBeTruthy();
    expect(
      screen.getByText(/docs\/superpowers\/specs\/<KEY>\.md/),
    ).toBeTruthy();
    expect(screen.getByText('never writes a line of app code')).toBeTruthy();
  });

  it('links charter ↗ to the agent .md on GitHub main', () => {
    render(<AgentProfileCard agent={sa} />);
    const link = screen.getByRole('link', { name: /charter/ });
    expect(link.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/solutions-architect.md',
    );
  });

  it('renders no charter link when file is null (YOU card)', () => {
    render(
      <AgentProfileCard
        agent={{ ...sa, ini: 'YOU', name: 'you', tier: 'human', file: null }}
      />,
    );
    expect(screen.queryByRole('link', { name: /charter/ })).toBeNull();
    expect(screen.getByText('HUMAN')).toBeTruthy();
  });
});
