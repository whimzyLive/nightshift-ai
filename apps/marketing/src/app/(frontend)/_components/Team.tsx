import { Eyebrow, Card } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function Team({ content }: { content?: Home['team'] }) {
  const agents = content?.agents ?? [];
  return (
    <section id="agents" className="mx-auto max-w-5xl px-6 py-24">
      {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
      {content?.intro ? (
        <p className="mt-4 max-w-2xl text-lg text-body">{content.intro}</p>
      ) : null}
      <div className="mt-10 grid gap-6 sm:grid-cols-3">
        {agents.map((agent, i) => (
          <Card key={agent.id ?? i}>
            <div className="font-semibold text-strong">{agent.name ?? ''}</div>
            <div className="mt-1 font-mono text-sm text-muted">
              {agent.role ?? ''}
            </div>
          </Card>
        ))}
      </div>
    </section>
  );
}
