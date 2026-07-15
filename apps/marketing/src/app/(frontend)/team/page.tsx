import { DepartmentOrgChart } from '../../../components/team/department-org-chart';
import { HandbookTerminal } from '../../../components/team/handbook-terminal';
import { TeamHero } from '../../../components/team/hero';
import { PhilosophyStrip } from '../../../components/team/philosophy-strip';
import { TeamCta } from '../../../components/team/team-cta';
import { teamMetadata } from '../../../lib/seo/metadata';

import type { Metadata } from 'next';

export const metadata: Metadata = teamMetadata;

// Synchronous server component, no async, no data fetch, no `dynamic`
// export — the roster/philosophy/handbook content is static TypeScript
// (see components/team/roster-data.ts), so this page statically prerenders
// at build time (unlike /why-sdlc and /faq, which read Payload's Local API).
export default function TeamPage() {
  return (
    <>
      <TeamHero />
      <PhilosophyStrip />
      <DepartmentOrgChart />
      <HandbookTerminal />
      <TeamCta />
    </>
  );
}
