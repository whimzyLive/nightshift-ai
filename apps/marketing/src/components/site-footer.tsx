import { Footer } from '@nightshift-ai/ui';

import { FOOTER_COLUMNS } from '../content/site';

export function SiteFooter() {
  return (
    <Footer
      logoSrc="/brand/logomark.svg"
      tagline="Your AI software team that ships while you sleep."
      columns={FOOTER_COLUMNS}
      builtOn="Built on Claude Code — agents, commands, skills, and hooks all the way down."
      bottomNote="MIT © whimzyLive"
    />
  );
}

export default SiteFooter;
