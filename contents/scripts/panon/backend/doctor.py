"""Run with the same Python selected in Panon's settings. No third-party imports required."""
import importlib
import json
import shutil
import sys


def diagnose():
    checks = []
    for module, required in [("numpy", True), ("websockets", True), ("dbus", True),
                             ("PIL", True), ("pykakasi", False), ("jaconv", False)]:
        try:
            importlib.import_module(module)
            checks.append(dict(name=module, required=required, ok=True))
        except Exception as error:
            checks.append(dict(name=module, required=required, ok=False, error=str(error)))
    for executable in ("pactl", "parec"):
        checks.append(dict(name=executable, required=False, ok=bool(shutil.which(executable)),
                           feature="audio capture"))
    return dict(python=sys.executable, version=sys.version.split()[0], checks=checks)


if __name__ == "__main__":
    report = diagnose()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    sys.exit(any(c["required"] and not c["ok"] for c in report["checks"]))
