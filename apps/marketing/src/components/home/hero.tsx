import {
  Badge,
  CtaButton,
  InstallSnippet,
  MagneticCta,
  Reveal,
  RevealGroup,
  Terminal,
} from '@nightshift-ai/ui';

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

// B2 settle spring (from the AC) — exempt from EASE_OUT (spring-driven).
const SETTLE_SPRING = { stiffness: 120, damping: 18 };

/**
 * Above-the-fold hero: value line, install snippets, GitHub star CTA, and
 * the scripted Terminal preview. Server component — the client boundary
 * lives only inside InstallSnippet/Terminal.
 */
export function Hero() {
  return (
    <section
      className="relative"
      style={{
        padding: 'clamp(1.25rem, 4.5vh, 5.75rem) 0 clamp(1rem, 3.5vh, 4.75rem)',
      }}
    >
      <div
        className="relative z-[1] mx-auto grid grid-cols-1 items-center gap-x-12 gap-y-8 md:grid-cols-[1fr_1.12fr]"
        style={{ maxWidth: 'var(--container-max)' }}
      >
        <RevealGroup>
          <Reveal
            spring={SETTLE_SPRING}
            style={{ marginBottom: 'clamp(0.625rem, 2.2vh, 1.75rem)' }}
          >
            <span className="inline-flex items-center gap-2">
              <Badge variant="accent" dot>
                v0.4.0 · MIT
              </Badge>
              <Badge variant="neutral">a Claude Code plugin</Badge>
            </span>
          </Reveal>
          <Reveal spring={SETTLE_SPRING}>
            <h1
              className="font-sans font-extrabold"
              style={{
                // Cap the hero display by viewport *height* too, so short
                // laptops shrink it enough to keep the whole fold on screen.
                fontSize: 'min(var(--display-clamp-hero), 6.6vh)',
                lineHeight: 1.04,
                letterSpacing: '-0.025em',
                color: 'var(--moon-100)',
                margin: '0 0 clamp(0.75rem, 2.2vh, 1.75rem)',
              }}
            >
              Your AI software team that ships{' '}
              <a href="#workflow" style={{ color: 'var(--accent)' }}>
                while you sleep
              </a>
            </h1>
          </Reveal>
          <Reveal
            as="p"
            spring={SETTLE_SPRING}
            style={{
              fontSize: 'clamp(0.9375rem, 2.2vh, 1.25rem)',
              lineHeight: 1.7,
              color: 'var(--text-muted)',
              maxWidth: '31.25rem',
              margin: '0 0 clamp(0.75rem, 2.4vh, 1.75rem)',
            }}
          >
            A Claude Code plugin that turns one terminal into a full delivery
            team — product manager, architect, tech lead, engineers, and QA. It
            reads a Jira ticket and ships the spec, plan, code, and review.
          </Reveal>
          <Reveal spring={SETTLE_SPRING}>
            <div
              className="flex flex-col"
              style={{
                maxWidth: '32.5rem',
                gap: 'clamp(0.375rem, 1vh, 0.625rem)',
              }}
            >
              <span
                className="font-mono uppercase"
                style={{
                  fontSize: '0.8125rem',
                  letterSpacing: '0.14em',
                  color: 'var(--text-dim)',
                }}
              >
                Install in 60 seconds
              </span>
              <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" />
              <InstallSnippet command="/plugin install sdlc@nightshift" />
              <MagneticCta className="mt-1 self-start">
                <CtaButton
                  href={GITHUB_URL}
                  target="_blank"
                  rel="noopener"
                  variant="secondary"
                >
                  ★ Star nightshift on GitHub
                </CtaButton>
              </MagneticCta>
            </div>
          </Reveal>
        </RevealGroup>
        <div className="relative">
          <div
            aria-hidden="true"
            className="pointer-events-none absolute rounded-full blur-[60px]"
            style={{
              top: '-7rem',
              left: '-6rem',
              width: '32rem',
              height: '32rem',
              background:
                'radial-gradient(circle, var(--terra-glow), transparent 66%)',
            }}
          />
          <Terminal
            title="zsh — acme-api · claude code"
            video={{
              src: '/hero-promo.mp4',
              poster: '/hero-promo-poster.jpg',
            }}
            minHeight="clamp(16.25rem, 40vh, 26.25rem)"
          />
        </div>
      </div>
    </section>
  );
}
