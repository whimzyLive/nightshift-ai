import { Eyebrow } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function HowItWorks({ content }: { content?: Home['howItWorks'] }) {
  const steps = content?.steps ?? [];
  return (
    <section id="how-it-works" className="mx-auto max-w-5xl px-6 py-24">
      {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
      <ol className="mt-10 grid gap-8 sm:grid-cols-3">
        {steps.map((step, i) => (
          <li key={step.id ?? i}>
            <div className="font-mono text-sm text-accent">
              {String(i + 1).padStart(2, '0')}
            </div>
            <div className="mt-2 font-semibold text-strong">
              {step.title ?? ''}
            </div>
            <div className="mt-1 text-sm text-muted">{step.body ?? ''}</div>
          </li>
        ))}
      </ol>
      {content?.autoRunCaption ? (
        <p className="mt-8 text-sm text-dim">{content.autoRunCaption}</p>
      ) : null}
    </section>
  );
}
