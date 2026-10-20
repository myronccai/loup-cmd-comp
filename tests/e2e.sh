#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree, built under $TMP.
W="$TMP/w"
mkdir -p "$W/bak" "$W/empty" "$W/sub"
printf 'abcdef\n' > "$W/a.txt"
printf 'abXdeY\n' > "$W/b.txt"
printf 'abcdef\n' > "$W/c.txt"
printf 'ABCDEF\n' > "$W/upper.txt"
printf 'abc\n' > "$W/short.txt"
printf 'one\ntwo\nthree\n' > "$W/l1.txt"
printf 'one\ntwX\nthree and more\n' > "$W/l2.txt"
printf '0123456789ABCDEFGHIJ' > "$W/n1.bin"
printf 'abcdefghijklmnopqrst' > "$W/n2.bin"
printf 'x\xe9\x00' > "$W/hi1.bin"
printf 'x\x41\x01' > "$W/hi2.bin"
: > "$W/empty1"
: > "$W/empty2"
cp "$W/a.txt" "$W/bak/a.txt"
printf 'abXdeF\n' > "$W/bak/b.txt"
cp "$W/a.txt" "$W/bak/a.bak"
cp "$W/a.txt" "$W/a.bak"
printf 'abcdef\nmore\n' > "$W/long.txt"
printf 'sub\n' > "$W/sub/s.txt"
cd "$W"

usage_text=$(build_usage() {
    printf '%s\n' \
        'COMP [data1] [data2] [/D] [/A] [/L] [/N=number] [/C] [/OFF[LINE]] [/M]' \
        '' \
        'Compares two files, or two sets of files, byte by byte.' \
        '' \
        '  data1, data2  The files to compare. Wildcards select sets of files; a' \
        '                directory means every file in it (data1) or the files' \
        '                with the same names (data2).' \
        '  /D            Show differing bytes as decimal numbers.' \
        '  /A            Show differing bytes as characters.' \
        '  /L            Report line numbers instead of byte offsets.' \
        '  /N=number     Compare only the first number lines of each file.' \
        '  /C            Ignore the case of ASCII letters.' \
        '  /OFF[LINE]    Accepted; has no effect on Linux.' \
        '  /M            Accepted; this version never asks to compare more files.' \
        '' \
        'ERRORLEVEL: 0 the files match, 1 they differ, 2 a file could not be opened.'
    printf '.'
}; build_usage)
usage_text=${usage_text%.}

# Help and version.
check_both "/? help"              0 "$usage_text" ''      '/?'
check      "-? with files"        0 "$usage_text"         a.txt b.txt '-?'
check      "--help"               0 "$usage_text"         --help
check      "--version"            0 $'comp (loup-cmd-comp) 0.1.0\n' --version

# One pair.
ok_ac=$'Comparing a.txt and c.txt...\nFiles compare OK\n\n'
check_both "equal files"          0 "$ok_ac" ''           a.txt c.txt
check      "/M changes nothing"   0 "$ok_ac"              a.txt c.txt /M
check      "/OFFLINE, /OFF"       0 "$ok_ac"              /OFFLINE a.txt /off c.txt
check      "empty files"          0 $'Comparing empty1 and empty2...\nFiles compare OK\n\n' empty1 empty2
diff_ab=$'Comparing a.txt and b.txt...\nCompare error at OFFSET 2\nfile1 = 63\nfile2 = 58\nCompare error at OFFSET 5\nfile1 = 66\nfile2 = 59\n\n'
check_both "two differences"      1 "$diff_ab" ''         a.txt b.txt
check      "lower-case switch"    1 "$diff_ab"            a.txt b.txt /m
check      "/D decimal" 1 $'Comparing a.txt and b.txt...\nCompare error at OFFSET 2\nfile1 = 99\nfile2 = 88\nCompare error at OFFSET 5\nfile1 = 102\nfile2 = 89\n\n' a.txt b.txt /D
check      "/A characters" 1 $'Comparing a.txt and b.txt...\nCompare error at OFFSET 2\nfile1 = c\nfile2 = X\nCompare error at OFFSET 5\nfile1 = f\nfile2 = Y\n\n' a.txt b.txt -a
check      "/A then /D: last wins" 1 $'Comparing a.txt and b.txt...\nCompare error at OFFSET 2\nfile1 = 99\nfile2 = 88\nCompare error at OFFSET 5\nfile1 = 102\nfile2 = 89\n\n' a.txt b.txt /A /D
check      "hex without padding" 1 $'Comparing hi1.bin and hi2.bin...\nCompare error at OFFSET 1\nfile1 = E9\nfile2 = 41\nCompare error at OFFSET 2\nfile1 = 0\nfile2 = 1\n\n' hi1.bin hi2.bin
check      "/C ignores case"      0 $'Comparing a.txt and upper.txt...\nFiles compare OK\n\n' a.txt upper.txt /C
cased=$(printf 'Comparing a.txt and upper.txt...\n'; for i in 0 1 2 3 4 5; do printf 'Compare error at OFFSET %X\nfile1 = %X\nfile2 = %X\n' $i $((0x61 + i)) $((0x41 + i)); done; printf '\n.')
check      "case counts without /C" 1 "${cased%.}"            a.txt upper.txt
check_both "different sizes"      1 $'Comparing a.txt and short.txt...\nFiles are different sizes.\n' '' a.txt short.txt
ten="Comparing n1.bin and n2.bin..."$'\n'
for i in 0 1 2 3 4 5 6 7 8 9; do
    ten+="Compare error at OFFSET $i"$'\n'"file1 = 3$i"$'\n'"file2 = $(printf '%X' $((0x61 + i)))"$'\n'
done
ten+=$'10 Mismatches - ending compare\n\n'
check      "stops after ten"      1 "$ten"                n1.bin n2.bin

# /L and /N.
check      "/L line numbers"      1 $'Comparing l1.txt and l2.txt...\nCompare error at LINE 2\nfile1 = 6F\nfile2 = 58\n\n' l1.txt l2.txt /L /N=2
check      "/N=1 equal start"     0 $'Comparing l1.txt and l2.txt...\nFiles compare OK\n\n' l1.txt l2.txt /n=1
check      "/N:3 sizes differ"    1 $'Comparing l1.txt and l2.txt...\nCompare error at OFFSET 6\nfile1 = 6F\nfile2 = 58\nCompare error at OFFSET D\nfile1 = A\nfile2 = 20\nFiles are different sizes.\n' l1.txt l2.txt /N:3
check      "/N with different sizes" 0 $'Comparing a.txt and long.txt...\nFiles compare OK\n\n' a.txt long.txt /N=1 /A
# The first lines differ in length here, so the common part is compared.
check      "/N line lengths differ" 1 $'Comparing short.txt and a.txt...\nCompare error at OFFSET 3\nfile1 = A\nfile2 = 64\nFiles are different sizes.\n' short.txt a.txt /N=1

# Paths and sets.
check      "backslash paths"      0 $'Comparing bak\\a.txt and a.txt...\nFiles compare OK\n\n' 'bak\a.txt' a.txt
check      "absolute path"        0 "Comparing $(printf '%s' "$W/a.txt" | tr / '\\') and c.txt..."$'\nFiles compare OK\n\n' "$W/a.txt" c.txt
check      "data2 is a directory" 0 $'Comparing a.txt and bak\\a.txt...\nFiles compare OK\n\n' a.txt bak
check_both "wildcard set"         2 $'Comparing a.txt and bak\\a.txt...\nFiles compare OK\n\nComparing b.txt and bak\\b.txt...\nCompare error at OFFSET 5\nfile1 = 59\nfile2 = 46\n\n' \
    $'Can\'t find/open file: bak\\c.txt\n'                '?.txt' 'bak\'
check      "wildcard data2"       0 $'Comparing a.bak and bak\\a.bak...\nFiles compare OK\n\nComparing a.txt and bak\\a.bak...\nFiles compare OK\n\n' \
    'a.*' 'bak\*.bak'
check      "data1 is a directory" 1 $'Comparing bak\\a.bak and a.bak...\nFiles compare OK\n\nComparing bak\\a.txt and a.txt...\nFiles compare OK\n\nComparing bak\\b.txt and b.txt...\nCompare error at OFFSET 5\nfile1 = 46\nfile2 = 59\n\n' \
    bak '*.*'
check      "dir to dir"           0 $'Comparing sub\\s.txt and sub\\s.txt...\nFiles compare OK\n\n' sub 'sub\'
check      "upper-case wildcard"  0 $'Comparing a.txt and c.txt...\nFiles compare OK\n\n' 'A.TX?' c.txt

# Missing files and bad arguments: ERRORLEVEL 2.
check_both "missing first"        2 '' $'Can\'t find/open file: nope.txt\n'        nope.txt a.txt
check_both "missing second"       2 '' $'Can\'t find/open file: sub\\nope.txt\n'   a.txt sub/nope.txt
check_both "no wildcard match"    2 '' $'Can\'t find/open file: *.zip\n'           '*.zip' bak
check_both "empty directory"      2 '' $'Can\'t find/open file: empty\\*.*\n'      empty bak
check_both "wildcard in data2 dir" 2 '' $'Could not expand second file name so as to match first\n' a.txt 'b*\a.txt'
check_both "bad /N"               2 '' $'Invalid switch - /N=x\n'                  a.txt b.txt /N=x
check_both "/N without a number"  2 '' $'Invalid switch - /n\n'                    a.txt b.txt /n
check_both "undeclared switch"    2 '' $'Invalid switch - /X\n'                    a.txt b.txt /X
check_both "a third file"         2 '' $'Invalid switch - c.txt\n'                 a.txt b.txt c.txt
check_both "-- ends switches"     2 '' $'Can\'t find/open file: \\D\n'             a.txt -- /D

# Missing names are asked for; the answers are read from standard input.
printf 'a.txt\nb.txt\n/A /L\n\n' > "$TMP/answers"
IN="$TMP/answers" check_both "prompted names and options" 1 \
    $'Name of first file to compare:\nName of second file to compare:\nOption :\nOption :\nComparing a.txt and b.txt...\nCompare error at LINE 1\nfile1 = c\nfile2 = X\nCompare error at LINE 1\nfile1 = f\nfile2 = Y\n\n' ''
printf 'c.txt\n' > "$TMP/answers"
IN="$TMP/answers" check "prompted second name" 0 \
    $'Name of second file to compare:\nOption :\nComparing a.txt and c.txt...\nFiles compare OK\n\n' a.txt
check_both "no answers"           2 $'Name of first file to compare:\n' ''

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
