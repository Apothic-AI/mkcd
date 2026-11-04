# mkcd

Create a directory if it does not exist, then `cd` into it.

```bash
mkcd projects/new-api
```

One command instead of `mkdir -p projects/new-api && cd projects/new-api`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Apothic-AI/mkcd/main/install.sh | bash
```

The installer puts `mkcd` and `cdmk` in `/usr/local/bin` when it can write
there, and in `~/.local/bin` otherwise, then adds a small block to your shell
rc file (`~/.bashrc` or `~/.zshrc`) that sources both scripts.

Restart your shell afterwards, or run `source ~/.bashrc`.

## Usage

```bash
mkcd ~/src/mkcd            # creates ~/src/mkcd, then changes into it
mkcd /var/log              # an existing directory is just entered
mkcd a b c                 # creates all three, then changes into the last one
mkcd --help                # usage
```

`cdmk` is an alias of `mkcd` and does exactly the same thing:

```bash
cdmk projects/new-api
```

A leading `~` is expanded, a path that exists but is not a directory is
reported as an error, and the directory that was created is printed on
stderr so stdout only ever holds the directory you ended up in.

## How the `cd` works

A script cannot change the directory of the shell that started it, so
`mkcd` is written to be sourced. The installer adds this to your rc file:

```bash
# >>> mkcd >>>

source "/usr/local/bin/mkcd"
source "/usr/local/bin/cdmk"
# <<< mkcd <<<
```

Sourcing defines `mkcd` and `cdmk` as shell functions, and a function can
change the directory of the shell it runs in. Run the scripts as plain
programs and the directory change applies to that program alone, which is
why they print a note about it.

You can also source them by hand:

```bash
source /usr/local/bin/mkcd
mkcd ~/projects
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/Apothic-AI/mkcd/main/install.sh | bash -s -- --uninstall
```

This removes both scripts and the block from your rc files.

## Options

`install.sh` takes a few options:

| Option | What it does |
| --- | --- |
| `--prefix DIR` | install into `DIR/bin` instead of the default location |
| `--uninstall` | remove an existing installation |
| `--no-rc` | leave the shell rc file alone |
| `-h`, `--help` | show the help |

| Variable | What it does |
| --- | --- |
| `MKCD_REPO` | repository to install from (default `Apothic-AI/mkcd`) |
| `MKCD_REF` | branch or tag to install (default `main`) |
| `MKCD_BASE_URL` | base URL to download from, overrides the two above |

## Requirements

Bash or Zsh, and `curl` or `wget` for the installer.

## Development

```bash
./tests/test.sh
```

The tests cover the scripts themselves and run under both Bash and Zsh.
