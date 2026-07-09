import { AgentCard, Eyebrow } from '@nightshift-ai/ui';

import { TEAM } from '../../content/site';
import styles from './team.module.css';

export function Team() {
  return (
    <section id="agents" className={styles.section}>
      <div className="ns-container">
        <div className={styles.intro}>
          <Eyebrow>// The team</Eyebrow>
          <h2 className={styles.header}>A team, not a megaprompt</h2>
          <p className={styles.body}>
            &quot;Do everything&quot; agents hallucinate across roles and leave no trail.
            nightshift splits the work across 11 agents, each with a tight charter, its own
            prompt and tools, and a clean handoff to the next. Narrow charters mean fewer
            hallucinations and an auditable artifact at every stage.
          </p>
          <p className={styles.roleList}>
            Product Manager · Architect · Tech Lead · Engineers · QA — each a separate agent,
            each leaving a document behind: PRD, spec, plan, review.
          </p>
        </div>

        <div className={styles.grid}>
          {TEAM.map((agent) => (
            <AgentCard key={agent.name} {...agent} />
          ))}
        </div>
      </div>
    </section>
  );
}

export default Team;
