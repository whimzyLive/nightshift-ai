import { render, screen } from '@testing-library/react';

import { DepartmentOrgChart } from './department-org-chart';
import { DEPARTMENTS } from './roster-data';

describe('DepartmentOrgChart', () => {
  it('renders the YOU card', () => {
    render(<DepartmentOrgChart />);
    expect(screen.getByText('YOU')).toBeTruthy();
  });

  it('renders all five department eyebrows', () => {
    render(<DepartmentOrgChart />);
    for (const dept of DEPARTMENTS) {
      expect(screen.getByText(dept.eyebrow)).toBeTruthy();
    }
  });

  it('renders a card for every roster member', () => {
    render(<DepartmentOrgChart />);
    for (const member of DEPARTMENTS.flatMap((d) => d.members)) {
      expect(screen.getByText(member.name)).toBeTruthy();
    }
  });
});
