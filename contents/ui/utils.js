function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
}
function localPath(url) {
    const value = String(url)
    if (!value.startsWith("file:///")) throw new Error("Panon requires a local installation")
    return decodeURIComponent(value.slice(7))
}
function chdir_scripts_root(url) {
    return "cd " + shellQuote(localPath(url)) + " && "
}
