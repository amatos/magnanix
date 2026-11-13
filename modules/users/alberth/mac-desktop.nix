# User:      alberth (den.aspects.alberth.macDesktop)
# Platforms: darwin (and home-manager through mas)
# Purpose:   alberth's Mac desktop: their Dock and the macOS apps they want on
#            every Mac they use as primary user.
#
# Notes:
# - Opt-in per host: included from den.aspects.<host>.provides.alberth next to
#   den.batteries.primary-user. The Dock is applied to the host's primary user
#   (system.primaryUser), so only include this where that is alberth.
# - Everything here is macOS-only, so including it on a NixOS host does nothing.
{ den, ... }:
{
  den.aspects.alberth.macDesktop = {
    includes = [
      den.aspects.alberth.macos.dock
      den.aspects.macos.appInspection
      den.aspects.macos.macMouseFix
      den.aspects.macos.mas
      den.aspects.macos.setapp
      den.aspects.macos.skim
      den.aspects.macos.spamsieve
      den.aspects.macos.supaSideBar
    ];
  };
}
