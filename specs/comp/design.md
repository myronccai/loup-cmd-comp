# Design: comp

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with
the shared switch parser (`win.switches`), handles `/?` and `--version`,
asks for missing file names on standard input (`cli.prompt`), and calls
`commands.comp.run_comp`. `run_comp` builds a plan (a list of `Pair`s: two
files, or an operand that failed with its message), then compares each
pair with the pure function `compare_data`, which returns the lines to
print and the pair's status.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses 0, 1, 2 |
| `source/cli/args.loup` | `Options`, `comp_switches()`, `parse_args` via `win.switches`, the display modes |
| `source/cli/prompt.loup` | `answer_lines`, `complete_args`: the prompts for missing names and options |
| `source/cli/usage.loup` | `usage()` (the `/?` summary), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, prompts, run, exceptions to status 2 |
| `source/commands/comp.loup` | `plan`, `first_files`, `second_file`, `map_name`, `compare_data`, `line_prefix`, `format_byte`, `hex`, `run_comp` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### Switches

`comp_switches()` declares `D`, `A`, `L`, `C`, `M`, `OFF`, `OFFLINE` as
flags and `N` as `optional_value("N", "0123456789")`, so `/N=10`, `/N:10`
and `/N10` give a value and `/N` alone is caught by `parse_args`
(`Invalid switch - /N`). The display mode is the last of `/A` and `/D` in
command-line order. More than two operands is an error naming the third.

### Planning

- `first_files(data1)`: a wildcard expands with `win.wildcard.expand`
  (`MATCH_FILES`); a directory gives all its files (`list_matches(dir, "*")`);
  anything else is the path itself, checked later.
- `second_file(data2, file1)`: a wildcard name maps `file1`'s name through
  `map_name` (base and extension separately: `*` copies the rest, `?` one
  character); a directory, or a name ending with a separator, gets
  `file1`'s name; otherwise data2 itself.
- No data1 files is `Can't find/open file: DATA1` (`DIR\*.*` for an empty
  directory); a wildcard in data2's directory part is `Could not expand
  second file name so as to match first`.

### Comparing

`compare_data(d1, d2, opts)` works on `bytes` (`readBytes`):

1. Without `/N`, different lengths give `Files are different sizes.` only.
2. `line_prefix(data, n)` is the length of the first `n` lines (through the
   n-th LF); without `/N` it is the whole length.
3. The common length is compared byte by byte; `fold_byte` upper-cases
   ASCII letters under `/C`. Each difference adds the location (offset in
   `hex`, or the line of file 1 counted from LFs), `file1 = ` and
   `file2 = ` lines (`format_byte`). The tenth adds
   `10 Mismatches - ending compare` and stops.
4. With `/N`, parts of different lengths end with
   `Files are different sizes.` (no blank line, as without `/N`). Otherwise
   `Files compare OK` when nothing differed, then a blank line.

### Prompts

With fewer than two operands, `run` reads standard input once (the only way
Loup 1.26.0 can read it) and `complete_args` turns its lines into answers:
one per missing name, then `Option :` answers (switches separated by
spaces) until an empty line or the end of input. Each prompt is printed on
its own line, since the answers are not echoed. The completed command line
is parsed again.

## Differences from the original

- Behaves as if `/M` were always given: it never asks
  `Compare more files (Y/N) ?` (standard input can only be read whole in
  Loup 1.26.0, roadmap constraint T2). Prompts for missing names read the
  lines of standard input, after it has been read to the end.
- `/OFF[LINE]` changes nothing: Linux files have no offline attribute.
- `/A` shows bytes from 0x80 up as Latin-1 characters (UTF-8 encoded), not
  in the console code page.
- `/N` with parts of different lengths: the common part is compared, then
  `Files are different sizes.` is printed (the original's behaviour here is
  not documented).
- The offset stays hexadecimal under `/D`; only the byte values change.
- File names are case-sensitive on Linux; wildcards ignore case. No 8.3
  short names.
- Errors (`Can't find/open file:`, `Invalid switch -`) go to standard
  error; messages end with LF, not CRLF.
- An unreadable file (permissions) ends the program with the toolchain's
  `IoError` message: Loup 1.26.0 has no `stat()` and a native `IoError`
  cannot be caught.
- `/?` prints this project's own short summary, not Microsoft's help text.
- `--version` and `--help` (alone) are series conventions, not Windows'.

## Error handling

Each pair's failure is reported and the next pair is compared; the exit
status is the highest seen (0 same, 1 different, 2 cannot open). Usage
errors exit with 2 before comparing anything. An unexpected exception is
printed on standard error and gives status 2.

## Testing

- `tests/args_test.loup`: switches, display mode order, `/N` values, extra
  operands, `/?`, `--`.
- `tests/prompt_test.loup`: answers from input lines, missing input.
- `tests/comp_test.loup`: `hex`, `format_byte`, `fold_byte`,
  `line_prefix`, `compare_data` (equal, differing, sizes, ten mismatches,
  `/L`, `/N`, `/C`, display modes), `map_name`, `first_files`,
  `second_file`, `plan` against a fixture tree in `build/tmp/`.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: runs the native binary in a fixture tree under `$TMP` and
  compares standard output byte for byte, standard error and the status.
