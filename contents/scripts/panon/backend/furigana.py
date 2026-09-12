"""Conservative, offline ruby alignment; never change the original lyric text."""

import re
import unicodedata
from functools import lru_cache

try:
    import jaconv
    from pykakasi import kakasi
except ImportError:
    jaconv = None
    kakasi = None

KANJI = re.compile(r"[\u3400-\u9fff々〆ヶ]+")
KANA = re.compile(r"[ぁ-ゖァ-ヺ]")
PARTS = re.compile(r"[\u3400-\u9fff々〆ヶ]+|[ぁ-ゖァ-ヺー]+|[^\u3400-\u9fff々〆ヶぁ-ゖァ-ヺー]+")


@lru_cache(maxsize=1)
def converter():
    return kakasi() if kakasi else None


def reading_kana(text):
    if jaconv is None:
        return ""
    text = unicodedata.normalize("NFKC", text).lower()
    for src, dst in zip("āīūēō", ("aa", "ii", "uu", "ee", "ou")):
        text = text.replace(src, dst)
    # Convert separately: joining 'n a' first would incorrectly produce な.
    text = re.sub(r"[a-z']+", lambda m: jaconv.alphabet2kana(m[0]), text)
    text = jaconv.kata2hira(text)
    if re.search(r"[a-z\u3400-\u9fff]", text):
        return ""
    return "".join(re.findall(r"[ぁ-ゖー]", text))


def align(text, reading):
    """Return ruby only when kana anchors give one unambiguous full alignment."""
    if not reading or len(text) > 300 or len(reading) > 600:
        return None
    parts = PARTS.findall(text)
    if any(re.search(r"[A-Za-z0-9]", p) for p in parts):
        return None

    @lru_cache(maxsize=None)
    def walk(i, offset):
        if i == len(parts):
            return ((),) if offset == len(reading) else ()
        part = parts[i]
        if KANJI.fullmatch(part):
            candidates = [(end, reading[offset:end]) for end in
                          range(offset + 1, min(len(reading), offset + len(part) * 8) + 1)]
        else:
            anchor = reading_kana(part)
            variants = {anchor}
            # Sung particles may be romanized by pronunciation rather than spelling.
            if anchor in ("は", "へ", "を"):
                variants.add({"は": "わ", "へ": "え", "を": "お"}[anchor])
            candidates = [(offset + len(a), "") for a in variants
                          if reading.startswith(a, offset)]
        found = []
        for end, ruby in candidates:
            for suffix in walk(i + 1, end):
                path = ((part, ruby),) + suffix
                if path not in found:
                    found.append(path)
                if len(found) == 2:
                    return tuple(found)
        return tuple(found)

    paths = walk(0, 0)
    if len(paths) != 1:
        return None
    return [{"text": text, "reading": ruby} for text, ruby in paths[0]]


@lru_cache(maxsize=1024)
def annotate(text, platform_reading=""):
    if not KANJI.search(text):
        return []
    official = align(text, reading_kana(platform_reading))
    if official:
        return [dict(part, source="netease" if part["reading"] else "") for part in official]
    engine = converter()
    if engine is None:
        return []
    result = []
    for token in engine.convert(text):
        original = token["orig"]
        parts = align(original, reading_kana(token["hira"])) if KANJI.search(original) else None
        if parts is None:
            parts = [{"text": original, "reading": token["hira"] if KANJI.search(original) else ""}]
        result.extend(dict(part, source="local" if part["reading"] else "") for part in parts)
    return result


def annotate_lines(title, lines, readings):
    # Han characters alone are not language evidence. Kana in title OR lyrics is.
    japanese = bool(KANA.search(title) or any(KANA.search(text) for _, text in lines))
    if not japanese:
        return [[] for _ in lines]
    result = []
    for timestamp, text in lines:
        matches = [r for t, r in readings if abs(t - timestamp) <= 0.35]
        result.append(annotate(text, matches[0] if len(matches) == 1 else ""))
    return result
