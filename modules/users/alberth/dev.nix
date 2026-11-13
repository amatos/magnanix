# User:      alberth (den.aspects.alberth.dev)
# Platforms: home-manager (and whatever the language aspects add)
# Purpose:   alberth's development tool set: the language toolchains and the
#            GitHub CLI.
#
# Notes:
# - Opt-in per host: included from den.aspects.<host>.provides.alberth, so
#   only alberth gets it, not every user on the host. Headless hosts leave it
#   out.
# - Python isn't here: base gives it to every host.
{ den, ... }:
{
  den.aspects.alberth.dev = {
    includes = [
      den.aspects.c
      den.aspects.elixir
      den.aspects.github
      den.aspects.go
      den.aspects.javascript
      den.aspects.kotlin # includes den.aspects.java
      den.aspects.lua
      den.aspects.ocaml
      den.aspects.php
      den.aspects.ruby
      den.aspects.rust
      den.aspects.shellscript
      den.aspects.swift
      den.aspects.zig
    ];
  };
}
