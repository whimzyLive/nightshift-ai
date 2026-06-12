# nightshift

Local Claude Code plugin marketplace (`nightshift`). Hosts the `sdlc` plugin.

    /plugin marketplace add <path-to-nightshift>
    /plugin install sdlc@nightshift

`sdlc` declares a cross-marketplace dependency on `superpowers@claude-plugins-official`; installing
it reuses an existing superpowers install or pulls it from the official marketplace automatically.
