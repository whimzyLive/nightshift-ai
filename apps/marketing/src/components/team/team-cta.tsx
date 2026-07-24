import {
  CtaButton,
  InstallSnippet,
  MagneticCta,
  Reveal,
  RevealGroup,
} from '@nightshift-ai/ui';

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

/**
 * Full-bleed install CTA — team.dc.html L198-213. Mirrors home's
 * final-cta.tsx layout (glow backdrop + centered column + star button).
 */
export function TeamCta() {
  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen overflow-hidden border-t"
      style={{
        padding: '84px 28px',
        borderColor: 'var(--border-default)',
      }}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute left-1/2 -translate-x-1/2 rounded-full blur-[10px]"
        style={{
          bottom: -160,
          width: 420,
          height: 420,
          background:
            'radial-gradient(circle, var(--terra-glow), transparent 62%)',
        }}
      />
      <RevealGroup
        as="div"
        className="relative z-[1] mx-auto text-center"
        style={{ maxWidth: 640 }}
      >
        <Reveal
          as="h2"
          style={{
            fontSize: 'clamp(28px, 3.4vw, 38px)',
            letterSpacing: '-0.02em',
            color: 'var(--moon-100)',
            margin: '0 0 14px',
          }}
        >
          Hire the whole team in 60 seconds
        </Reveal>
        <Reveal
          as="p"
          style={{
            fontSize: 16,
            lineHeight: 1.6,
            color: 'var(--text-muted)',
            margin: '0 0 26px',
          }}
        >
          No interviews, no onboarding docs, no salaries. One config file per
          repo and they start tonight.
        </Reveal>
        <Reveal
          className="mx-auto flex flex-col gap-[10px] text-left"
          style={{ maxWidth: 560, marginBottom: 22 }}
        >
          <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" />
          <InstallSnippet command="/plugin install sdlc@nightshift" />
        </Reveal>
        <Reveal className="flex justify-center">
          <MagneticCta>
            <CtaButton
              variant="secondary"
              size="lg"
              href={GITHUB_URL}
              target="_blank"
              rel="noopener"
            >
              ★ Star nightshift on GitHub
            </CtaButton>
          </MagneticCta>
        </Reveal>
        <Reveal as="p" style={{ margin: '22px 0 0' }}>
          <a
            href="/"
            className="font-mono"
            style={{ fontSize: 13.5, color: 'var(--link)' }}
          >
            ← Back to overview
          </a>
        </Reveal>
      </RevealGroup>
    </section>
  );
}
