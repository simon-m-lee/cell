"""One-shot docstring trimmer for the AI-facing doc cleanup.

Usage (from repo root):
  python tool/trim_ai_docs.py
"""
import re
import pathlib

FIELD_RE = re.compile(
    r'^\s*\*\*(Layer|When to use|When NOT to use|Live signature|'
    r'Do NOT confuse with|Guide|Example|Cross-layer|Stability|'
    r'Self-verification[^*]*|Minimal compilable example[^*]*)\**\s*:?'
)


def is_doc_line(line):
    return line.lstrip().startswith('///')


def strip_doc(line):
    return re.sub(r'^\s*/// ?', '', line)


def is_bullet(text):
    return text.startswith(('- ', '  - ', '* ', '  * ')) or text.startswith('    ')


def trim_ai_block(lines):
    """Keep: header, the 7 required fields (+ Cross-layer), When-NOT-to-use
    continuations, bullet content under When-to-use, and the Minimal
    compilable example fence. Drop: Stability, Self-verification, free
    prose paragraphs, and anything after the closing fence."""
    out = []
    current = None
    in_snippet = False
    in_fence = False
    fence_done = False
    for line in lines:
        if not is_doc_line(line):
            out.append(line)
            continue
        if fence_done:
            continue
        doc = strip_doc(line)
        m = FIELD_RE.match(doc)
        if m:
            field = m.group(1)
            if field == 'Minimal compilable example':
                in_snippet = True
                current = 'snippet'
                out.append(line)
            elif in_snippet:
                out.append(line)
            elif field in ('Layer', 'When to use', 'When NOT to use',
                           'Live signature', 'Do NOT confuse with',
                           'Guide', 'Example', 'Cross-layer'):
                current = field
                out.append(line)
            else:
                current = field  # Stability / Self-verification: dropped
            continue
        if in_snippet:
            t = doc.strip()
            if t.startswith('```') and not in_fence:
                in_fence = True
                out.append(line)
            elif t.startswith('```') and in_fence:
                in_fence = False
                fence_done = True
                out.append(line)
            else:
                out.append(line)
            continue
        stripped = doc.strip()
        if current == 'When NOT to use' and stripped:
            out.append(line)
            continue
        if current == 'When to use' and is_bullet(stripped):
            out.append(line)
            continue
        if stripped.startswith('### AI Agent Guide'):
            out.append(line)
    return out


def trim_nonobvious(lines):
    """Remove `### Non-obvious` / `### Non-obvious` sections from doc
    comments. A section runs until the next `### ` heading or the end of
    the doc comment."""
    out = []
    in_section = False
    for line in lines:
        if is_doc_line(line):
            stripped = strip_doc(line).strip()
            if stripped.startswith('### Non') and 'bvious' in stripped:
                in_section = True
                continue
            if in_section:
                if stripped.startswith('### ') or stripped.startswith('## '):
                    in_section = False
                    out.append(line)
                continue
            out.append(line)
        else:
            in_section = False
            out.append(line)
    return out


def main():
    changed = 0
    for pkg in ['cell', 'cell_flow', 'cell_tissue']:
        for f in pathlib.Path('packages', pkg, 'lib').rglob('*.dart'):
            src = f.read_text(encoding='utf-8')
            lines = src.split('\n')
            new_lines = []
            i = 0
            modified = False
            while i < len(lines):
                line = lines[i]
                if (is_doc_line(line) and
                        strip_doc(line).strip().startswith('### AI Agent Guide')):
                    j = i
                    while j < len(lines) and is_doc_line(lines[j]):
                        j += 1
                    block = lines[i:j]
                    trimmed = trim_ai_block(block)
                    new_lines.extend(trimmed)
                    if trimmed != block:
                        modified = True
                    i = j
                    continue
                new_lines.append(line)
                i += 1
            src2 = '\n'.join(new_lines)
            new_lines2 = trim_nonobvious(src2.split('\n'))
            src3 = '\n'.join(new_lines2)
            if src3 != src2:
                modified = True
            if modified:
                f.write_text(src3, encoding='utf-8')
                changed += 1
                print('trimmed', f)
    print('files changed:', changed)


if __name__ == '__main__':
    main()
