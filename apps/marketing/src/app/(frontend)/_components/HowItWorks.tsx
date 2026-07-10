import { Eyebrow } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function HowItWorks({ content }: { content?: Home['howItWorks'] }) {
  const steps = content?.steps ?? [];
  return (
    <section
      id="how-it-works"
      className="border-t border-default px-6 py-20 sm:py-24"
    >
      <div className="mx-auto max-w-page">
        {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
        <ol className="mt-10 grid gap-8 sm:grid-cols-3">
          {steps.map((step, i) => (
            <li key={step.id ?? i}>
              <div className="flex h-8 w-8 items-center justify-center rounded-sm border border-line-accent font-mono text-sm text-accent">
                {String(i + 1).padStart(2, '0')}
              </div>
              <div className="mt-3 font-semibold text-strong">
                {step.title ?? ''}
              </div>
              <div className="mt-1 text-sm text-muted">{step.body ?? ''}</div>
            </li>
          ))}
        </ol>
        {content?.autoRunCaption ? (
          <p className="mt-10 max-w-copy border-l-2 border-default pl-4 font-mono text-xs leading-relaxed text-dim">
            {content.autoRunCaption}
          </p>
        ) : null}
      </div>
    </section>
  );
}
