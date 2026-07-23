'use client';

import { RichText } from '@payloadcms/richtext-lexical/react';
import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';

import { AnimatePresence, motion } from 'motion/react';

import {
  EASE_OUT,
  Eyebrow,
  GateCheck,
  prefersReducedMotion,
} from '@nightshift-ai/ui';

import { useScrollProgress } from './scroll-progress';

import type { WhySdlcArgument } from '../../lib/why-sdlc';

// Matches the retired `ns-gatepulse` keyframes (1.6s, scale + brightness).
const GATE_PULSE_ANIMATE = {
  scale: [1, 1.14, 1],
  filter: ['brightness(1)', 'brightness(1.45)', 'brightness(1)'],
};

// Verbatim captions from the design handoff (why-sdlc.dc.html L381-387,
// `renderVals`'s `CAPTIONS`) — decorative UI copy, not editable CMS content
// (see spec Open Question 2).
const CAPTIONS = [
  'what one-shot abstraction hands you',
  'how software teams already ship',
  'five gates — control returns at each',
  'one opaque blob vs five reviewable units',
  'the same principles, one verb at a time',
];

const GATE_NAMES = ['refine', 'spec', 'plan', 'implement', 'review'];

function VisLine({
  children,
  color = 'var(--moon-200)',
}: {
  children: ReactNode;
  color?: string;
}) {
  return (
    <span
      className="font-mono block"
      style={{ fontSize: 13.5, lineHeight: 1.8, color }}
    >
      {children}
    </span>
  );
}

// The five static, in-code mono illustrations for the sticky pane — mirrors
// how `control-section.tsx` co-locates its own terminal scripts. Transcribed
// from the design handoff's five `.vis-layer` blocks (why-sdlc.dc.html
// L182-236), condensed to fit a single reviewable component.
const ILLUSTRATIONS: ReactNode[] = [
  <div key="0" className="flex flex-col gap-2">
    <VisLine color="var(--text-dim)">// one-shot abstraction</VisLine>
    <VisLine>&gt; build the-whole-feature</VisLine>
    <VisLine color="var(--text-dim)">thinking … you can&apos;t see in</VisLine>
    <VisLine color="var(--amber-400)">4,213 lines · no say in how</VisLine>
    <VisLine color="var(--red-400)">
      ❓ &quot;no, like this…&quot; — after the fact
    </VisLine>
  </div>,
  <div key="1" className="flex flex-col gap-2">
    <VisLine color="var(--text-dim)">// incremental — how teams ship</VisLine>
    <VisLine color="var(--moon-100)">epic</VisLine>
    <VisLine>
      ├── story-1{' '}
      <span style={{ color: 'var(--text-dim)' }}>· small, reviewable</span>
    </VisLine>
    <VisLine>├── story-2</VisLine>
    <VisLine>
      │&nbsp;&nbsp;&nbsp;└── implementation{' '}
      <span style={{ color: 'var(--green-400)' }}>✓ tests</span>
    </VisLine>
    <VisLine>└── story-3</VisLine>
    <VisLine color="var(--text-dim)">
      smaller pieces — easier to diagnose, test, release, and control
    </VisLine>
  </div>,
  <div key="2" className="flex flex-col gap-3.5">
    <VisLine color="var(--text-dim)">// hard gates — control returns</VisLine>
    {GATE_NAMES.map((name) => (
      <div key={name} className="flex items-center gap-3.5">
        <span
          className="font-mono flex items-center justify-center"
          style={{
            width: 30,
            height: 30,
            border: '1px solid var(--border-accent)',
            color: 'var(--terra-400)',
            background: 'var(--terra-tint)',
            fontSize: 14,
          }}
        >
          ⊘
        </span>
        <span
          className="font-mono"
          style={{ fontSize: 14, color: 'var(--moon-200)' }}
        >
          {name}
        </span>
        <span
          className="font-mono ml-auto"
          style={{ fontSize: 11, color: 'var(--text-dim)' }}
        >
          you approve →
        </span>
      </div>
    ))}
  </div>,
  <div key="3" className="flex flex-col gap-2">
    <VisLine color="var(--text-dim)">// one shot vs small units</VisLine>
    <VisLine color="var(--moon-100)">one shot:</VisLine>
    <VisLine color="var(--red-400)">████████████████ ❓ read it all</VisLine>
    <VisLine color="var(--moon-100)">gated:</VisLine>
    {[
      'story · reviewed alone',
      'spec.md',
      'plan.md',
      'code + tests',
      'review → PR',
    ].map((line) => (
      <VisLine key={line}>
        <span style={{ color: 'var(--green-400)' }}>✓</span> {line}
      </VisLine>
    ))}
  </div>,
  <div key="4" className="flex flex-col gap-2">
    <VisLine color="var(--text-dim)">// it works the way you would</VisLine>
    {['/refine-issue', '/spec', '/impl', '/review'].map((cmd) => (
      <VisLine key={cmd}>
        &gt; <span style={{ color: 'var(--terra-400)' }}>{cmd}</span> PROJ-142{' '}
        <span style={{ color: 'var(--green-400)' }}>✓</span>
      </VisLine>
    ))}
    <VisLine color="var(--green-400)">
      → PR ready. you stayed the developer.
    </VisLine>
    <VisLine color="var(--text-dim)">it did the typing.</VisLine>
  </div>,
];

interface GateNodeProps {
  index: number;
  reached: number;
  active: number;
  reduced: boolean;
}

function GateNode({ index, reached, active, reduced }: GateNodeProps) {
  const isCurrent = index === active;
  const isPassed = !isCurrent && index < reached;
  const state = isCurrent ? 'current' : isPassed ? 'passed' : 'idle';
  const color = state === 'idle' ? 'var(--text-dim)' : 'var(--terra-400)';
  const borderColor =
    state === 'idle' ? 'var(--border-default)' : 'var(--border-accent)';
  const background =
    state === 'passed'
      ? 'rgba(217,119,87,.3)'
      : state === 'current'
        ? 'rgba(217,119,87,.12)'
        : 'var(--bg-void)';
  const glow =
    state === 'current'
      ? '0 0 16px rgba(217,119,87,.55)'
      : state === 'passed'
        ? '0 0 8px rgba(217,119,87,.3)'
        : 'none';
  const pulse = state === 'current' && !reduced;

  return (
    <motion.span
      data-gate-state={state}
      className="font-mono flex items-center justify-center"
      animate={
        pulse ? GATE_PULSE_ANIMATE : { scale: 1, filter: 'brightness(1)' }
      }
      transition={
        pulse
          ? { duration: 1.6, ease: 'easeInOut', repeat: Infinity }
          : { duration: 0.2 }
      }
      style={{
        position: 'relative',
        zIndex: 1,
        width: 32,
        height: 32,
        border: `1px solid ${borderColor}`,
        color,
        background,
        fontSize: 15,
        boxShadow: glow,
        transition:
          'border-color .4s, color .4s, box-shadow .4s, background .4s',
      }}
    >
      {state === 'passed' ? <GateCheck reduced={reduced} /> : '⊘'}
    </motion.span>
  );
}

/**
 * `/why-sdlc` argument section — the two-column gate-rail scrollytelling
 * layout. Left: five argument cards (`data-why-sec={i}`, one per `args`
 * row) with a dashed gate rail; right: a sticky pane crossfading five
 * static in-code illustrations keyed to `active`. Consumes
 * `useScrollProgress()` for `{ reached, active }` — the single source of
 * truth shared with the CTA kicker (Task 5).
 */
export function ArgumentRail({ args }: { args: WhySdlcArgument[] }) {
  const { reached, active } = useScrollProgress();
  const activeIllustration = ILLUSTRATIONS[active] ?? ILLUSTRATIONS[0];
  const activeCaption = CAPTIONS[active] ?? CAPTIONS[0];
  const [reducedMotion, setReducedMotion] = useState(false);

  useEffect(() => setReducedMotion(prefersReducedMotion()), []);

  return (
    <section style={{ padding: '64px 28px 72px' }}>
      <div
        className="mx-auto grid grid-cols-1 items-start gap-8 lg:grid-cols-[1fr_400px]"
        style={{ maxWidth: 1220 }}
      >
        <div className="relative flex flex-col gap-[26px]">
          <div
            aria-hidden="true"
            className="absolute left-4 md:left-[27px]"
            style={{
              top: 44,
              bottom: 44,
              width: 0,
              borderLeft: '1px dashed rgba(217,119,87,.4)',
            }}
          />
          {args.map((arg, i) => (
            <div
              key={i}
              data-why-sec={i}
              className="relative grid grid-cols-[32px_1fr] gap-3 md:grid-cols-[56px_1fr] md:gap-6"
            >
              <div className="flex items-start justify-center pt-[30px]">
                <GateNode
                  index={i}
                  reached={reached}
                  active={active}
                  reduced={reducedMotion}
                />
              </div>
              <div
                data-lift
                className="px-5 py-7 md:px-[34px] md:py-[30px]"
                style={{
                  background: 'var(--surface-card)',
                  border: '1px solid var(--border-default)',
                }}
              >
                <Eyebrow>{arg.eyebrow.replace(/^\/\/\s*/, '')}</Eyebrow>
                <h2
                  style={{
                    fontSize: 26,
                    letterSpacing: '-0.02em',
                    color: 'var(--moon-100)',
                    margin: '12px 0 14px',
                  }}
                >
                  {arg.heading}
                </h2>
                <div
                  className="[&_p]:m-0 [&_p]:max-w-[66ch]"
                  style={{
                    fontSize: 17,
                    lineHeight: 1.75,
                    color: 'var(--text-body)',
                  }}
                >
                  <RichText data={arg.body} disableContainer />
                </div>
              </div>
            </div>
          ))}
        </div>

        <div
          className="sticky overflow-hidden"
          style={{
            top: 100,
            height: 500,
            background: 'var(--surface-terminal)',
            border: '1px solid var(--border-accent)',
            boxShadow: '0 0 26px rgba(217,119,87,.1)',
          }}
        >
          <div style={{ padding: '26px 28px' }}>
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={active}
                initial={reducedMotion ? false : { opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={reducedMotion ? undefined : { opacity: 0 }}
                transition={{
                  duration: reducedMotion ? 0 : 0.3,
                  ease: EASE_OUT,
                }}
              >
                {activeIllustration}
              </motion.div>
            </AnimatePresence>
          </div>
          <div
            className="absolute right-0 bottom-0 left-0"
            style={{
              padding: '12px 28px',
              borderTop: '1px solid var(--border-soft)',
              background: 'rgba(13,13,24,.8)',
            }}
          >
            <span
              className="font-mono"
              style={{ fontSize: 12, color: 'var(--accent)' }}
            >
              {`${active + 1}/${args.length} · ${activeCaption}`}
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}
