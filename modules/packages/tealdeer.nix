# Aspect:    den.aspects.tui.tealdeer (included by base)
# Platforms: home-manager
# Purpose:   tealdeer, a fast `tldr` client (short, example-based man pages).
#            auto_update refreshes the page cache when it gets old, so it never
#            needs a manual `tldr --update`.
{
  den.aspects.tui.tealdeer = {
    homeManager = {
      programs = {
        tealdeer = {
          enable = true;
          settings.updates.auto_update = true;
        };
      };
    };
  };
}
