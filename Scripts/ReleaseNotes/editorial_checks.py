"""Enforce the measurable parts of the release-note writing standard."""

import re

MAX_RELEASE_BULLETS = 5
MAX_ENGLISH_TITLE_WORDS = 6
MAX_CHINESE_TITLE_CHARACTERS = 20
MAX_ENGLISH_BULLET_WORDS = 20
MAX_CHINESE_BULLET_CHARACTERS = 60

ENGLISH_FILLER = (
    "we're excited", "we are excited", "we're thrilled", "we are thrilled",
    "seamless", "seamlessly", "game-changing", "cutting-edge", "next-level",
    "powerful", "robust", "delve", "leverage", "better than ever",
    "enhanced user experience", "improved user experience", "various improvements",
)
CHINESE_FILLER = (
    "重磅", "焕然一新", "赋能", "无缝体验", "全新体验", "体验全面升级", "多项优化", "多项改进",
)
GENERIC_ENGLISH_CHANGE = re.compile(
    r"^(?:improved (?:performance|stability)|bug fixes(?: and improvements)?|"
    r"(?:performance|stability)(?: and (?:performance|stability))? improvements)[.!]?$",
    re.IGNORECASE,
)
GENERIC_CHINESE_CHANGE = re.compile(r"^(?:修复错误|修复了一些错误|修复若干问题|性能优化|提升性能|提升稳定性|优化体验)[。！]?$")


def validate_copy_style(text, *, location, is_title):
    english_limit = MAX_ENGLISH_TITLE_WORDS if is_title else MAX_ENGLISH_BULLET_WORDS
    chinese_limit = MAX_CHINESE_TITLE_CHARACTERS if is_title else MAX_CHINESE_BULLET_CHARACTERS
    if len(text["en"].split()) > english_limit:
        raise ValueError(f"{location}: English copy exceeds {english_limit} words. Keep one concrete change and remove extra words.")
    if len(text["zh-Hans"]) > chinese_limit:
        raise ValueError(f"{location}: Chinese copy exceeds {chinese_limit} characters. Keep one concrete change and remove extra words.")
    for language, value in text.items():
        if value != value.strip():
            raise ValueError(f"{location} ({language}): Remove leading or trailing whitespace.")
    normalized_english = text["en"].casefold().replace("’", "'")
    for phrase in ENGLISH_FILLER:
        if re.search(r"\b" + re.escape(phrase).replace(r"\ ", r"\s+") + r"\b", normalized_english):
            raise ValueError(f"{location} (en): Replace filler '{phrase}' with the specific user-visible change.")
    for phrase in CHINESE_FILLER:
        if phrase in text["zh-Hans"]:
            raise ValueError(f"{location} (zh-Hans): Replace filler '{phrase}' with the specific user-visible change.")
    if not is_title and (
        GENERIC_ENGLISH_CHANGE.fullmatch(text["en"]) or GENERIC_CHINESE_CHANGE.fullmatch(text["zh-Hans"])
    ):
        raise ValueError(f"{location}: Name the affected feature and behavior; generic improvements are not release notes.")


def validate_release_editorial_standard(release):
    version = release["version"]
    validate_copy_style(release["title"], location=f"v{version} title", is_title=True)
    items = [item for section in release["sections"] for item in section["items"]]
    if len(items) > MAX_RELEASE_BULLETS:
        raise ValueError(f"v{version}: Use at most {MAX_RELEASE_BULLETS} bullets. Prioritize the changes users need to know.")
    seen_copy = {"en": set(), "zh-Hans": set()}
    for index, item in enumerate(items, start=1):
        location = f"v{version} bullet {index}"
        validate_copy_style(item, location=location, is_title=False)
        for language, value in item.items():
            normalized = " ".join(value.casefold().split()).rstrip(".!。！")
            if normalized in seen_copy[language]:
                raise ValueError(f"{location} ({language}): Remove the repeated change.")
            seen_copy[language].add(normalized)
