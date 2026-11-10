# Languages

## Python

The `python` aspect (`modules/packages/languages/python.nix`, included by `alberth`) installs nixpkgs' default
`python3` for ad-hoc scripts and leaves per-project Python versions to uv. It also installs:

| Tool                                                   | Use                                                                         |
| ------------------------------------------------------ | --------------------------------------------------------------------------- |
| [uv](https://docs.astral.sh/uv)                        | projects, lockfiles, virtualenvs, Python versions, `uv build`, `uv publish` |
| [Ruff](https://docs.astral.sh/ruff)                    | linter and formatter (`ruff format` replaces Black)                         |
| [basedpyright](https://docs.basedpyright.com)          | type checker and language server                                            |
| [ty](https://docs.astral.sh/ty)                        | Astral's type checker and language server, still pre-1.0                    |

uv and Ruff are set up through Home Manager's `programs.uv` and `programs.ruff`, so global settings go in their
`settings` (`~/.config/uv/uv.toml`, `~/.config/ruff/ruff.toml`); a project's own config takes precedence. Tools a
project pins, such as mypy or Black, belong in its dev dependencies (`uv add --dev mypy`) or run with `uvx`.

uv downloads standalone Python builds, which are linked against a generic `/lib64` loader that NixOS doesn't
have. On NixOS the aspect enables `programs.nix-ld`, which provides one, so those builds run.

## Ruby

The `ruby` aspect (`modules/packages/languages/ruby.nix`, included by `alberth`) installs Ruby 4.0 (`ruby_4_0`)
through Home Manager. Ruby 4 ships gem, Bundler, irb, rake, debug and rbs. The aspect also installs:

| Tool                                                      | Use                                                                                     |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| [ruby-lsp](https://shopify.github.io/ruby-lsp)            | language server, built against Ruby 4                                                   |
| [RuboCop](https://rubocop.org)                            | linter and formatter                                                                    |
| [Standard](https://github.com/standardrb/standard)        | RuboCop with a fixed, zero-config style (`standardrb`)                                  |
| [bundler-audit](https://github.com/rubysec/bundler-audit) | `bundle-audit check --update` checks `Gemfile.lock` for gems with known vulnerabilities |
| [mise](https://mise.jdx.dev)                              | per-project Ruby versions from `.ruby-version` or `mise.toml`                           |

The Nix Ruby's gem directory is in the read-only store, so `gem install` and `bundle install` fall back to
`~/.local/share/gem/ruby/4.0.0`, whose `bin` is on `PATH`. RuboCop and Standard are built on nixpkgs' default Ruby
(3.4): their dependency unicode-emoji 4.1.0 declares `ruby < 4.0`, so the Ruby 4 builds fail at startup. A project
that lists either gem in its `Gemfile` uses its own copy through ruby-lsp.

mise is activated in every shell but sets no global Ruby, so the Nix Ruby is used outside projects that pin a
version. In a project, `mise use ruby@3.3` writes `mise.toml` and installs that version.

## Rust

The `rust` aspect (`modules/packages/languages/rust.nix`, included by `alberth`) installs the toolchain
through [rustup](https://rustup.rs) rather than a fixed nixpkgs `rustc`, so a project's `rust-toolchain.toml`
picks its own channel, components and targets. rustup's proxies provide `cargo`, `rustc`, `clippy`, `rustfmt`
and `rust-analyzer`; `~/.cargo/bin` is on `PATH` for anything installed with `cargo install`. It also installs:

| Tool                                                               | Use                                                          |
| ------------------------------------------------------------------ | ------------------------------------------------------------ |
| [cargo-edit](https://github.com/killercup/cargo-edit)              | `cargo upgrade` bumps dependency versions in `Cargo.toml`    |
| [cargo-nextest](https://nexte.st)                                  | faster test runner                                           |
| [cargo-llvm-cov](https://github.com/taiki-e/cargo-llvm-cov)        | source-based code coverage                                   |
| [cargo-audit](https://rustsec.org)                                 | checks dependencies against the RustSec advisory database    |
| [cargo-shear](https://github.com/Boshen/cargo-shear)               | finds unused dependencies                                    |
| [cargo-expand](https://github.com/dtolnay/cargo-expand)            | shows macro-expanded code                                    |
| [bacon](https://dystroy.org/bacon)                                 | background checker that reruns on file changes               |
| [taplo](https://taplo.tamasfe.dev)                                 | TOML formatter and language server, for `Cargo.toml`         |

rustup keeps its toolchains in `~/.rustup`, outside Nix, so after the first switch install one and the
component `cargo-llvm-cov` needs:

```sh
rustup default stable
rustup component add llvm-tools-preview
```

`cargo-llvm-cov` is built with its tests skipped (`doCheck = false`), so every host builds it locally instead of
fetching it from the binary cache. Its integration tests build coverage-instrumented binaries with nixpkgs'
`rustc`, and those segfault (seen on aarch64-darwin and x86_64-linux). The tool itself is unaffected: at runtime
it uses rustup's toolchain and `llvm-tools-preview`. Remove the override once nixpkgs fixes the tests (see
[TODO](todo.md#todo)).

## Other languages

Each aspect in `modules/packages/languages/` installs a language's runtime or compiler, its language server and
formatter through Home Manager. All of them are included by `alberth`.

| Aspect        | Installs                                                                                                   |
| ------------- | ---------------------------------------------------------------------------------------------------------- |
| `c`           | clang-tools (clangd, clang-format, clang-tidy), CMake, Ninja; on NixOS also GCC and gdb                    |
| `elixir`      | Erlang/OTP, Elixir and ElixirLS, all from one `beamPackages` set                                           |
| `go`          | Go (`programs.go`), gopls, golangci-lint, Delve; `~/go/bin` is on `PATH`                                   |
| `javascript`  | Node.js LTS (`programs.npm`), pnpm, Bun, Deno, TypeScript 5, typescript-language-server, Biome             |
| `kotlin`      | kotlinc, kotlin-language-server, ktlint, all on JDK 25; includes `java` for `JAVA_HOME`, Gradle and Maven  |
| `lua`         | LuaJIT (also as `lua`), LuaRocks, lua-language-server, StyLua                                              |
| `ocaml`       | OCaml, dune, ocaml-lsp, ocamlformat, opam                                                                  |
| `php`         | PHP, Composer, intelephense (unfree)                                                                       |
| `shellscript` | ShellCheck, shfmt, bash-language-server                                                                    |
| `swift`       | on NixOS: Swift, sourcekit-lsp, swift-format; nothing on macOS                                             |
| `zig`         | Zig and zls, kept on the same release                                                                      |

On macOS the C/C++ compiler, lldb and the whole Swift toolchain come from the Xcode Command Line Tools
(`xcode-select --install`), which match the SDKs, so the `c` and `swift` aspects don't install them there.

Global installs go to writable directories on `PATH`: `npm install -g` to `~/.npm` (the npm prefix set in
`~/.npmrc`), `pnpm add -g` to `PNPM_HOME`, Bun and Deno to `~/.bun/bin` and `~/.deno/bin`, `go install` to
`~/go/bin` and `composer global require` to `~/.config/composer/vendor/bin`.

nixpkgs' default `typescript` is TypeScript 7, the native compiler, which no longer ships the `tsserver.js` that
typescript-language-server falls back to when a project has no TypeScript in `node_modules`. The aspect installs
`typescript_5` instead; projects that use TypeScript 7 get it from their own dependencies.

The Nix OCaml (5.5.1), dune, ocaml-lsp and ocamlformat need no setup. They cover standard-library-only code and
projects that get their dependencies from Nix (`ocamlPackages` in a flake or `nix develop`). Run `opam init` once
only when a project:

- declares its dependencies in `*.opam` files and expects `opam install . --deps-only`,
- needs a library that isn't in nixpkgs' `ocamlPackages`, or
- needs a compiler other than 5.5.1 (create a switch for it, e.g. `opam switch create 4.14.2`).

opam is installed without shell integration, since `opam env` fails until `opam init` has run, so activate a switch
with `eval $(opam env)`. If opam becomes a regular tool, set `programs.opam.enable = true` in the `ocaml` aspect
instead (only once `~/.opam` exists), which runs `opam env` in every shell. The Nix ocaml-lsp only understands
projects built with OCaml 5.5.1; in a switch with another compiler, install `ocaml-lsp-server` and `ocamlformat`
into the switch (`opam install ocaml-lsp-server ocamlformat`) so the editor uses those.

Neovim keeps its own copies of shfmt, StyLua and lua-language-server on its private `PATH` (see [Neovim](neovim.md#neovim)),
so it doesn't depend on the `shellscript` and `lua` aspects.
