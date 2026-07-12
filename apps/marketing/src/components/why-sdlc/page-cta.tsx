import { CtaButton, InstallSnippet } from '@nightshift-ai/ui';

import { CtaKicker } from './cta-kicker';

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

/**
 * `/why-sdlc` page CTA — kicker, heading, install snippets, GitHub star
 * button, and the back-to-overview link. Server shell: the only client JS
 * is `CtaKicker` (reads scroll progress) and `InstallSnippet` (copy button),
 * matching the Home `FinalCta` split.
 */
export function PageCta() {
  return (
    <section
      className="relative border-t"
      style={{ padding: '84px 28px', borderColor: 'var(--border-default)' }}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute left-1/2 rounded-full blur-[10px]"
        style={{
          bottom: -160,
          transform: 'translateX(-50%)',
          width: 420,
          height: 420,
          background:
            'radial-gradient(circle, var(--terra-glow), transparent 62%)',
        }}
      />
      <div
        className="relative z-[1] mx-auto text-center"
        style={{ maxWidth: 640 }}
      >
        <CtaKicker />
        <h2
          style={{
            fontSize: 'clamp(28px, 3.4vw, 38px)',
            letterSpacing: '-0.02em',
            color: 'var(--moon-100)',
            margin: '0 0 26px',
          }}
        >
          Put the lifecycle back in your hands
        </h2>
        <div
          className="mx-auto flex flex-col gap-[10px] text-left"
          style={{ maxWidth: 560, marginBottom: 22 }}
        >
          <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" />
          <InstallSnippet command="/plugin install sdlc@nightshift" />
        </div>
        <div className="flex flex-wrap justify-center gap-3">
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
        <p style={{ margin: '22px 0 0' }}>
          <a
            href="/"
            className="font-mono"
            style={{ fontSize: 13.5, color: 'var(--link)' }}
          >
            ← Back to overview
          </a>
        </p>
      </div>
    </section>
  );
}
