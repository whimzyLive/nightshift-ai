import { NavBar } from '@nightshift-ai/ui';

import { NAV_LINKS, REPO_URL } from '../content/site';

export function SiteNav() {
  return (
    <NavBar
      logoSrc="/brand/logomark.svg"
      links={NAV_LINKS}
      ctaLabel="Install the plugin"
      ctaHref="#install"
      secondary={
        <a href={REPO_URL} target="_blank" rel="noreferrer">
          GitHub
        </a>
      }
    />
  );
}

export default SiteNav;
