#!/usr/bin/env python3
"""
Forensic Word Counter Utility
A simple, robust script to analyze text files, documentation, or Markdown transcripts.
"""

import argparse
import os
import sys

def analyze_text(file_path: str):
    """
    Reads a file and returns statistics on lines, words, and characters.
    """
    if not os.path.exists(file_path):
        print(f"Error: The file '{file_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading file '{file_path}': {e}", file=sys.stderr)
        sys.exit(1)

    # Calculate metrics
    char_count = len(content)
    char_count_no_spaces = len(content.replace(" ", "").replace("\n", ""))
    word_count = len(content.split())
    line_count = content.count('\n') + (1 if content else 0)

    return {
        "file": file_path,
        "lines": line_count,
        "words": word_count,
        "characters": char_count,
        "characters_no_spaces": char_count_no_spaces
    }

def main():
    parser = argparse.ArgumentParser(description="Count words, lines, and characters in a text file.")
    parser.add_argument("file", help="Path to the target text file (.txt, .md, etc.)")

    args = parser.parse_args()

    stats = analyze_text(args.file)

    print("-" * 40)
    print(f"File Analysis: {stats['file']}")
    print("-" * 40)
    print(f"  Lines              : {stats['lines']:,}")
    print(f"  Words              : {stats['words']:,}")
    print(f"  Characters (total) : {stats['characters']:,}")
    print(f"  Characters (no spc): {stats['characters_no_spaces']:,}")
    print("-" * 40)

if __name__ == "__main__":
    main()