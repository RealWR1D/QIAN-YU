#!/usr/bin/env python3
"""Check editable copy resources before building the app."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "QIAN_YU/Resources/EditorialContent.json"
CATALOGS = [
    ROOT / "QIAN_YU/Resources/Localizable.xcstrings",
    ROOT / "QIAN_YU/Widgets/Localizable.xcstrings",
]
PLACEHOLDERS = {
    "notification.context.course": {"courseCount", "totalMinutes", "remainingCount", "remainingMinutes"},
    "notification.context.entry": {"date", "kind", "userName", "course", "weather"},
    "notification.ai.prompt": {"contexts", "recent"},
    "persona.context": {"base", "userName", "timeContext"},
    "persona.course": {"course"},
    "persona.weather": {"weather"},
    "notification.lunch.title": {"userName"},
    "notification.course.pre.title": {"courseName"},
    "notification.course.pre.body": {"courseName", "classroom", "minutes"},
    "notification.course.post.title": {"courseName"},
    "notification.course.post.base": {"courseName"},
    "notification.course.post.next": {"base", "nextCourseName", "classroom"},
    "notification.course.post.done": {"base"},
    "dialogue.course.next": {"summary"},
    "dialogue.requestFailed": {"error"},
    "course.next.soon": {"courseName", "classroom", "minutes"},
    "course.next.ongoing": {"courseName", "classroom"},
    "course.addFailed": {"error"},
    "course.deleteFailed": {"error"},
    "course.toggleFailed": {"error"},
    "course.calendarSyncSuccess": {"count"},
    "course.calendarSyncFailed": {"error"},
}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"重复的 JSON 键：{key}")
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)


def main():
    content = read_json(CONTENT)
    strings = content["strings"]
    lists = content["lists"]
    assert all(isinstance(value, str) and value for value in strings.values())
    assert all(isinstance(values, list) and values and all(isinstance(v, str) and v for v in values)
               for values in lists.values())
    assert content["quickActions"] and all(item.get("title") and item.get("prompt")
                                           for item in content["quickActions"])

    for key, value in strings.items():
        actual = set(re.findall(r"\{([A-Za-z][A-Za-z0-9]*)\}", value))
        assert actual == PLACEHOLDERS.get(key, set()), f"{key} 的占位符有误：{actual}"
    assert "{userName}" in " ".join(lists["dialogue.default"])

    source = "\n".join(path.read_text(encoding="utf-8") for path in
                       (ROOT / "QIAN_YU").rglob("*.swift"))
    for kind, key in re.findall(r'EditorialCopy\.(text|list)\("([^"\\]+)"', source):
        if "\\(" not in key:
            assert key in (strings if kind == "text" else lists), f"未定义的文案键：{key}"

    for path in CATALOGS:
        catalog = read_json(path)
        assert catalog["strings"], f"空文案目录：{path}"
        for key, entry in catalog["strings"].items():
            if key:
                value = entry.get("localizations", {}).get("zh-Hans", {}).get("stringUnit", {}).get("value")
                assert isinstance(value, str) and value, f"缺少简体中文文案：{path}: {key}"

    print(f"文案检查通过：{len(strings)} 条固定文案，{len(lists)} 组台词，"
          f"{len(content['quickActions'])} 个快捷提问。")


if __name__ == "__main__":
    main()
