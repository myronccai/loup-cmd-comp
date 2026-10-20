# Requirements: comp

## Introduction

`comp` is the Windows command that compares two files, or two sets of
files, byte by byte and reports where they differ. This repository
recreates it in Loup for Linux, keeping Windows' operand syntax (`\`
separators, `*` and `?` wildcards expanded by the command itself, `/?`
help), output format, messages and ERRORLEVELs. The Windows conventions come
from the shared code in `source/win/` (master copy: loup-cmd-type).

## Requirements

### Requirement 1: Compare two files

**User Story:** As a cmd user, I want to know whether two files are
identical, and where they differ, so that I can check a copy.

#### Acceptance Criteria

1. WHEN two files are compared, THE program SHALL print
   `Comparing DATA1 and DATA2...` with the names as given (separators shown
   as `\`).
2. WHEN the files have the same bytes, THE program SHALL print
   `Files compare OK` and a blank line, and exit with status 0.
3. WHEN the files have different sizes and `/N` is not given, THE program
   SHALL print `Files are different sizes.` without comparing, and exit
   with status 1.
4. WHEN a byte differs, THE program SHALL print
   `Compare error at OFFSET X` (hexadecimal, upper case, no leading zeros),
   `file1 = V1` and `file2 = V2`; after the last difference it SHALL print a
   blank line and exit with status 1.
5. WHEN ten bytes have differed, THE program SHALL print
   `10 Mismatches - ending compare` and a blank line and stop comparing
   that pair.

### Requirement 2: Switches

**User Story:** As a cmd user, I want comp's switches so that I can choose
how differences are shown and what is compared.

#### Acceptance Criteria

1. THE program SHALL show differing bytes in hexadecimal by default (`61`),
   in decimal with `/D` (`97`) and as characters with `/A` (`a`); when both
   are given, the last one SHALL win.
2. WHEN `/L` is given, THE program SHALL print `Compare error at LINE N`,
   the 1-based line of the first file, instead of the offset.
3. WHEN `/N=number` (or `/N:number`) is given, THE program SHALL compare
   only the first `number` lines of each file, even if the files have
   different sizes; WHEN those parts have different lengths, it SHALL
   compare their common length and then print `Files are different sizes.`
4. WHEN `/C` is given, THE program SHALL treat ASCII letters of either case
   as equal.
5. THE program SHALL accept `/M` and `/OFF[LINE]` and ignore them.
6. THE program SHALL accept switches with `/` or `-`, in any case and
   anywhere on the command line; `--` SHALL end switch parsing; a `/X` that
   comp does not declare SHALL be a file name.
7. WHEN `/?` (or `-?`) is given, THE program SHALL print a short summary
   of the syntax and switches and exit with status 0.

### Requirement 3: Sets of files

**User Story:** As a cmd user, I want to compare sets of files so that I
can check a whole backup at once.

#### Acceptance Criteria

1. WHEN data1 contains `*` or `?` in its last component, THE program SHALL
   compare every matching file (Windows wildcard rules, sorted by name).
2. WHEN data1 is a directory, THE program SHALL compare every file in it.
3. WHEN data2 is a directory (or ends with a separator), THE program SHALL
   compare each data1 file with the file of the same name in it.
4. WHEN data2 contains wildcards, THE program SHALL map each data1 name
   through it (`*.bak` turns `a.txt` into `a.bak`).
5. THE exit status SHALL be the highest of the pairs' statuses.

### Requirement 4: Errors and prompts

**User Story:** As a script author, I want comp's messages and ERRORLEVELs
so that scripts written for Windows behave the same.

#### Acceptance Criteria

1. WHEN a file cannot be found, THE program SHALL print
   `Can't find/open file: NAME` on standard error, go on with the next
   pair, and exit with status 2.
2. WHEN `/N` has no positive number, or a third operand is given, THE
   program SHALL print `Invalid switch - TEXT` on standard error and exit
   with status 2.
3. WHEN data1 or data2 is missing, THE program SHALL ask for it
   (`Name of first file to compare:`, `Name of second file to compare:`),
   then ask for more switches (`Option :`) until an empty answer, reading
   the answers from the lines of standard input; WHEN the input ends before
   a file name, it SHALL exit with status 2.
4. THE program SHALL never ask `Compare more files (Y/N) ?` (it behaves as
   if `/M` were always given).
