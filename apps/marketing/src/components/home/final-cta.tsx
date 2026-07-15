import { CtaButton, Eyebrow, InstallSnippet } from '@nightshift-ai/ui';

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

/**
 * Home section 08 — Final CTA. Server component: the only client JS is
 * inside `InstallSnippet` (copy-to-clipboard) — the star button and the
 * ghost-text/glow backdrop are plain server-rendered markup, matching the
 * Hero's own split (see hero.tsx).
 */
export function FinalCta() {
  return (
    <section
      id="install"
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen overflow-hidden border-t"
      style={{
        padding: '88px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute rounded-full blur-[10px]"
        style={{
          bottom: -160,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 480,
          height: 320,
          background:
            'radial-gradient(circle, var(--terra-glow), transparent 65%)',
        }}
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute left-1/2 -translate-x-1/2 leading-none font-sans font-extrabold whitespace-nowrap select-none"
        style={{
          bottom: 18,
          fontSize: 'clamp(64px, 9.5vw, 140px)',
          letterSpacing: '-0.03em',
          color: 'rgba(245,243,239,0.035)',
        }}
      >
        you sleep, it ships
      </div>

      <div
        className="relative z-[1] mx-auto text-center"
        style={{ maxWidth: 720 }}
      >
        <Eyebrow>08 · install in 60 seconds</Eyebrow>
        <h2
          style={{
            fontSize: 'clamp(30px, 3.8vw, 42px)',
            lineHeight: 1.14,
            letterSpacing: '-0.02em',
            color: 'var(--moon-100)',
            margin: '14px 0 14px',
          }}
        >
          Put a ticket in tonight. Read a reviewed PR in the morning.
        </h2>
        <p
          className="mx-auto"
          style={{
            fontSize: 18,
            lineHeight: 1.6,
            color: 'var(--text-muted)',
            maxWidth: 560,
            margin: '0 auto 28px',
          }}
        >
          Install takes about a minute. Point it at a ticket and watch the spec,
          plan, code, and review land — with the paper trail linked back where
          your team already works.
        </p>
        <div
          className="mx-auto flex flex-col gap-[10px] text-left"
          style={{ maxWidth: 560, marginBottom: 24 }}
        >
          <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" />
          <InstallSnippet command="/plugin install sdlc@nightshift" />
        </div>
        <div className="flex justify-center">
          <CtaButton
            variant="secondary"
            size="lg"
            href={GITHUB_URL}
            target="_blank"
            rel="noopener"
          >
            ★ Star nightshift on GitHub
          </CtaButton>
        </div>
      </div>
    </section>
  );
}
