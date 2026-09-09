"""Gate print() calls in game_controller.gd behind `if _debug_enabled:`.

Dry-run by default; pass --apply to write changes.
"""
import re
import sys

PATH = 'Scripts/Core/game_controller.gd'

lines = open(PATH, encoding='utf-8').read().split('\n')


def indent_of(line):
    n = 0
    for c in line:
        if c == '\t':
            n += 1
        else:
            break
    return n


def scan_from(line, col, bal):
    """Scan one line from col, counting parens outside strings/comments.
    Returns (bal, in_string_char_or_None, backslash_continuation)."""
    i = col
    n = len(line)
    in_s = None
    while i < n:
        c = line[i]
        if in_s:
            if c == '\\':
                i += 2
                continue
            if c == in_s:
                in_s = None
            i += 1
            continue
        if c == '"' or c == "'":
            in_s = c
        elif c == '#':
            break
        elif c == '(':
            bal += 1
        elif c == ')':
            bal -= 1
        i += 1
    stripped = line.rstrip()
    cont = in_s is None and stripped.endswith('\\')
    return bal, in_s, cont


def statement_extent(start):
    """Given the line index of a `print(` statement start, return end line index."""
    m = re.match(r'^\t*print\(', lines[start])
    col = m.end() - 1  # position of '('
    bal = 0
    i = start
    while True:
        bal, in_s, cont = scan_from(lines[i], col if i == start else 0, bal)
        if bal <= 0 and in_s is None and not cont:
            return i
        i += 1
        if i >= len(lines):
            raise RuntimeError(f'unbalanced print at line {start + 1}')


def is_print_start(idx):
    return re.match(r'^\t*print\(', lines[idx]) is not None


def is_blank(idx):
    return lines[idx].strip() == ''


def is_comment(idx):
    return lines[idx].lstrip('\t').startswith('#')


# ---- collect print statements ----
prints = []  # (start, end, indent)
i = 0
while i < len(lines):
    if is_print_start(i):
        end = statement_extent(i)
        prints.append((i, end, indent_of(lines[i])))
        i = end + 1
    else:
        i += 1

print(f'print statements found: {len(prints)}')
multi = [(s, e) for s, e, _ in prints if e > s]
print(f'multi-line print statements: {len(multi)}')
for s, e in multi:
    print(f'  lines {s + 1}-{e + 1}')

# ---- group consecutive prints in the same block ----
groups = []  # list of [start_line, end_line] ranges to wrap
gi = 0
while gi < len(prints):
    s, e, ind = prints[gi]
    gstart, gend = s, e
    gj = gi + 1
    cursor = e + 1
    while gj < len(prints):
        ns, ne, nind = prints[gj]
        if nind != ind:
            break
        # lines between cursor and ns must be only blanks/comments
        between = list(range(cursor, ns))
        if all(is_blank(b) or is_comment(b) for b in between):
            gend = ne
            cursor = ne + 1
            gj += 1
        else:
            break
    groups.append((gstart, gend))
    gi = gj

total_gated = sum(
    1 for s, e, _ in prints for gs, ge in groups if gs <= s <= ge
)
print(f'groups: {len(groups)}, statements gated: {total_gated}')

if '--apply' not in sys.argv:
    print('dry run; re-run with --apply')
    sys.exit(0)

# ---- emit transformed file ----
group_starts = {gs: (gs, ge) for gs, ge in groups}
in_group = {}  # line idx -> True if inside a group (needs extra indent)
for gs, ge in groups:
    for idx in range(gs, ge + 1):
        in_group[idx] = True

out = []
for idx, line in enumerate(lines):
    if idx in group_starts:
        out.append('\t' * indent_of(line) + 'if _debug_enabled:')
    if idx in in_group:
        if line.strip() == '':
            out.append('' if line.strip() == '' else line)  # blank stays blank
        else:
            out.append('\t' + line)
    else:
        out.append(line)

open(PATH, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('applied')
