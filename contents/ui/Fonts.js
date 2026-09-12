.pragma library
function select(preferred, available, fallback) {
    if (preferred && available.indexOf(preferred) >= 0) return preferred
    const candidates = ["Noto Sans CJK JP", "Noto Sans JP", "Source Han Sans JP", "IPAexGothic"]
    for (const name of candidates) if (available.indexOf(name) >= 0) return name
    return fallback
}
