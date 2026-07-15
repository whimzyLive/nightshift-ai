import {
  CtaButton,
  InstallSnippet,
  Reveal,
  RevealGroup,
} from '@nightshift-ai/ui';

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

/**
 * `/faq` bottom install CTA — h2, two install snippets, GitHub star button,
 * back-to-overview link, terra glow. Server component: the only client JS
 * is inside `InstallSnippet` (copy-to-clipboard), mirroring
 * `home/final-cta.tsx`'s split.
 */
export function FaqCta() {
  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t text-center"
      style={{
        padding: '72px 28px',
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
          width: 420,
          height: 420,
          background:
            'radial-gradient(circle, var(--terra-glow), transparent 62%)',
        }}
      />
      <RevealGroup className="relative z-[1] mx-auto" style={{ maxWidth: 640 }}>
        <Reveal
          as="h2"
          style={{
            fontSize: 'clamp(26px, 3.2vw, 36px)',
            letterSpacing: '-0.02em',
            color: 'var(--moon-100)',
            margin: '0 0 14px',
          }}
        >
          Question answered? Put a ticket in tonight.
        </Reveal>
        <Reveal
          as="div"
          className="mx-auto flex flex-col gap-[10px] text-left"
          style={{ maxWidth: 560, marginBottom: 20 }}
        >
          <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" />
          <InstallSnippet command="/plugin install sdlc@nightshift" />
        </Reveal>
        <Reveal as="div" className="flex justify-center">
          <CtaButton
            variant="secondary"
            size="lg"
            href={GITHUB_URL}
            target="_blank"
            rel="noopener"
          >
            ★ Star nightshift on GitHub
          </CtaButton>
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
