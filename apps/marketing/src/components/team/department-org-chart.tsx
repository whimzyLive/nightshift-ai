import { AgentProfileCard } from './agent-profile-card';
import { DEPARTMENTS, YOU } from './roster-data';

/**
 * The org chart: standalone YOU card, dashed spine, five department
 * clusters — team.dc.html L131-180. The spine + YOU card render as one
 * visual unit (spec Open Question 3's suggested default).
 */
export function DepartmentOrgChart() {
  return (
    <section style={{ padding: '64px 28px 40px' }}>
      <div className="mx-auto" style={{ maxWidth: 1120 }}>
        <div className="relative">
          <div className="relative mx-auto" style={{ maxWidth: 480 }}>
            <div
              className="text-center"
              style={{
                background: 'var(--surface-card)',
                border: '1px solid rgba(110,196,138,.45)',
                padding: '20px 22px',
                display: 'flex',
                flexDirection: 'column',
                gap: 12,
              }}
            >
              <div
                className="font-mono font-bold"
                style={{ fontSize: 22, color: 'var(--green-400)' }}
              >
                {YOU.ini}
              </div>
              <div
                className="font-mono"
                style={{ fontSize: 15, color: 'var(--moon-100)' }}
              >
                {YOU.name} · {YOU.title}
              </div>
              <p
                style={{
                  fontSize: 14,
                  lineHeight: 1.6,
                  color: 'var(--text-muted)',
                  margin: 0,
                }}
              >
                Approves every gate. Reviews every PR. The only member who
                sleeps — the org is built around that.
              </p>
              <span
                className="font-mono"
                style={{ fontSize: 11, color: 'var(--text-dim)' }}
              >
                {YOU.flow}
              </span>
            </div>
          </div>

          {DEPARTMENTS.map((dept) => (
            <div
              key={dept.title}
              className="relative"
              style={{ marginTop: 46 }}
            >
              {/* Spine segment: fills only the gap above this section label —
                  connects the previous block's cards (or the YOU card) down to
                  the top of this "//" eyebrow, then stops. No line runs through
                  the label, heading, blurb, or card row. */}
              <div
                aria-hidden="true"
                className="absolute left-1/2 -top-[46px] h-[46px]"
                style={{
                  width: 0,
                  borderLeft: '1px dashed rgba(217,119,87,.4)',
                }}
              />
              <div className="relative mb-[18px] flex justify-center">
                <span
                  className="relative z-[1] inline-block whitespace-nowrap font-mono uppercase"
                  style={{
                    background: 'var(--bg-void)',
                    border: '1px solid var(--border-accent)',
                    color: 'var(--accent)',
                    fontSize: 12,
                    letterSpacing: '.14em',
                    padding: '7px 16px',
                  }}
                >
                  {dept.eyebrow}
                </span>
              </div>
              <h3
                className="text-center font-sans"
                style={{
                  fontSize: 18,
                  color: 'var(--moon-100)',
                  margin: '0 0 8px',
                }}
              >
                {dept.title}
              </h3>
              <p
                className="mx-auto text-center"
                style={{
                  fontSize: 14,
                  color: 'var(--text-dim)',
                  maxWidth: 560,
                  margin: '0 auto 20px',
                }}
              >
                {dept.blurb}
              </p>
              <div className="relative flex flex-wrap justify-center gap-[14px]">
                {dept.members.map((member) => (
                  <div key={member.name} style={{ width: 330 }}>
                    <AgentProfileCard agent={member} />
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
