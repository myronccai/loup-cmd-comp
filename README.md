# loup-cmd-comp

The Windows `comp` command recreated in [Loup](https://code-craft.ai/references/loup):
compare two files, or two sets of files, byte by byte, with comp's output,
switches, wildcards, messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                              # native binary: build/comp
make ci                                 # check, unit tests, build, end-to-end tests
make run ARGS="README.md AGENTS.md"     # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ build/comp 'demo\letter.txt' 'demo\backup\letter.txt'
Comparing demo\letter.txt and demo\backup\letter.txt...
Files compare OK

$ build/comp 'demo\letter.txt' 'demo\letter2.txt'
Comparing demo\letter.txt and demo\letter2.txt...
Compare error at OFFSET 7
file1 = 77
file2 = 57
Compare error at OFFSET C
file1 = 2E
file2 = 21

$ build/comp 'demo\letter.txt' 'demo\letter2.txt' /A
Comparing demo\letter.txt and demo\letter2.txt...
Compare error at OFFSET 7
file1 = w
file2 = W
Compare error at OFFSET C
file1 = .
file2 = !

$ build/comp 'demo\letter.txt' 'demo\letter2.txt' /D /C
Comparing demo\letter.txt and demo\letter2.txt...
Compare error at OFFSET C
file1 = 46
file2 = 33

$ build/comp 'demo\notes.txt' 'demo\backup\notes.txt' /L /A
Comparing demo\notes.txt and demo\backup\notes.txt...
Compare error at LINE 2
file1 = t
file2 = T
Compare error at LINE 2
file1 = w
file2 = W
Compare error at LINE 2
file1 = o
file2 = O

$ build/comp 'demo\*.txt' 'demo\backup' 2>&1; echo "ERRORLEVEL $?"
Comparing demo\letter.txt and demo\backup\letter.txt...
Files compare OK

Can't find/open file: demo\backup\letter2.txt
Comparing demo\notes.txt and demo\backup\notes.txt...
Compare error at OFFSET E
file1 = 74
file2 = 54
Compare error at OFFSET F
file1 = 77
file2 = 57
Compare error at OFFSET 10
file1 = 6F
file2 = 4F

ERRORLEVEL 2
$ build/comp 'demo\letter.txt' 'demo\backup\short.txt'; echo "ERRORLEVEL $?"
Comparing demo\letter.txt and demo\backup\short.txt...
Files are different sizes.
ERRORLEVEL 1
$ build/comp 'demo\letter.txt' 'demo\backup\short.txt' /N=1
Comparing demo\letter.txt and demo\backup\short.txt...
Compare error at OFFSET 5
file1 = 2C
file2 = A
Files are different sizes.
$ printf 'demo\\letter.txt\ndemo\\letter2.txt\n/C\n\n' | build/comp
Name of first file to compare:
Name of second file to compare:
Option :
Option :
Comparing demo\letter.txt and demo\letter2.txt...
Compare error at OFFSET C
file1 = 2E
file2 = 21

$ build/comp 'demo\missing.txt' 'demo\letter.txt'; echo "ERRORLEVEL $?"
Can't find/open file: demo\missing.txt
ERRORLEVEL 2
$ build/comp a b /N=x; echo "ERRORLEVEL $?"
Invalid switch - /N=x
ERRORLEVEL 2
$ build/comp --version
comp (loup-cmd-comp) 0.1.0
```

```text
COMP [data1] [data2] [/D] [/A] [/L] [/N=number] [/C] [/OFF[LINE]] [/M]
```

| Switch | Effect |
|---|---|
| `/D` | show differing bytes in decimal |
| `/A` | show differing bytes as characters (the last of `/A` and `/D` wins) |
| `/L` | report the line number (of the first file) instead of the offset |
| `/N=number` | compare only the first `number` lines of each file, even if their sizes differ (`/N:number` works too) |
| `/C` | ignore the case of ASCII letters |
| `/M` | accepted; comp never asks to compare more files here anyway |
| `/OFF[LINE]` | accepted and ignored |
| `/?` | a summary of the syntax and switches |

Switches start with `/` or `-`, in any case, anywhere on the command line; a
`/X` that comp does not know is a file name (so `/tmp/a.txt` works), and
`--` ends switch parsing.

- **data1** may be a file, a wildcard pattern (`*.txt`: every matching file,
  Windows rules, sorted by name) or a directory (every file in it).
- **data2** may be a file, a directory (each data1 file is compared with the
  file of the same name in it) or a wildcard pattern that maps each data1
  name (`*.bak` turns `a.txt` into `a.bak`).
- Without `/N`, files of different sizes are not compared. A pair stops
  after ten differing bytes (`10 Mismatches - ending compare`).
- With a file name missing, comp asks for it, then for more switches
  (`Option :`) until an empty answer. The answers are the lines of
  standard input.

Exit status (ERRORLEVEL): `0` if every pair compared equal, `1` if a pair
differs (in content or size), `2` if a file cannot be found or opened, or
for a bad switch. With several pairs, the highest status wins.

## Differences from the original

- comp always behaves as if `/M` were given: it never asks
  `Compare more files (Y/N) ?`, because Loup 1.26.0 can only read standard
  input whole (roadmap constraint T2). For the same reason the prompts for
  missing names wait for the end of standard input, then take its lines as
  the answers, and each prompt is printed on its own line.
- `/OFF[LINE]` changes nothing: Linux files have no offline attribute.
- `/A` shows bytes from 0x80 up as Latin-1 characters (written as UTF-8),
  not in the console code page.
- The output layout (a blank line after `Files compare OK` and after the
  differences, none after `Files are different sizes.`) follows published
  Windows 10 examples; the original's behaviour for `/N` when the first
  lines of the two files have different lengths is not documented, so this
  version compares their common part and then prints
  `Files are different sizes.`
- The offset stays hexadecimal with `/D`; only the byte values change.
- Errors (`Can't find/open file:`, `Invalid switch -`) go to standard error.
  Messages end with LF, not CRLF.
- File names are case-sensitive on Linux; wildcards ignore case. No 8.3
  short names, so `*.txt` does not also match `a.txtx`. Paths are printed
  with `\`.
- An unreadable file (permissions) stops the program with the toolchain's
  `IoError` message instead of `Can't find/open file:`: Loup 1.26.0 has no
  `stat()`, and a native `IoError` cannot be caught.
- `/?` prints this project's own short summary of the syntax and switches,
  not Microsoft's help text.
- `--help` and `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses 0/1/2
source/cli/args.loup          # comp's switches via win.switches
source/cli/prompt.loup        # the prompts for missing names and options
source/cli/usage.loup         # /? and --version text
source/cli/app.loup           # run(): parse, prompts, run, exit status
source/commands/comp.loup     # plan the pairs, compare bytes, print
source/win/                   # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/comp (make e2e)
specs/comp/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
