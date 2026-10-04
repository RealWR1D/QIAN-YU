#!/usr/bin/env python3
"""Export the canonical guide for the website or a distribution attachment."""
from __future__ import annotations

import argparse
from pathlib import Path
import re


def export(source: str, section: str | None = None) -> str:
    source = re.sub(r'\n## 目录\n.*?(?=\n## \d+\.)', '\n', source, flags=re.S)
    source = re.sub(r'^## \d+\. ', '## ', source, flags=re.M)
    if section:
        pattern = r'^## ' + re.escape(section) + r'\n(.*?)(?=^## |\Z)'
        match = re.search(pattern, source, flags=re.M | re.S)
        if not match:
            raise ValueError(f'Guide section not found: {section}')
        body = match[1].split('\n---\n\n项目：', 1)[0].strip()
        return '# ' + section + '\n\n' + body + '\n'
    # The website generates chapter numbering and navigation automatically.
    if not re.search(r'^> ', source.split('\n\n', 2)[1]):
        source = source.replace('\n', '\n\n> 依据 2026 年 10 月 4 日项目源码编写 · QIAN YU 使用文档\n', 1)
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--section')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent / 'Docs' / '千语使用指南.md'
    args.output.write_text(export(source.read_text(encoding='utf-8'), args.section), encoding='utf-8')


if __name__ == '__main__':
    main()
