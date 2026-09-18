"""Actual QML timing regression check; requires PySide6 and KDE QML modules."""
import os
from pathlib import Path

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

app = QGuiApplication([])
engine = QQmlEngine()
path = Path(__file__).resolve().parents[1] / 'contents/ui/LyricTicker.qml'
component = QQmlComponent(engine, QUrl.fromLocalFile(str(path)))
item = component.create()
assert item is not None, '\n'.join(error.toString() for error in component.errors())
item.setProperty('width', 100)
item.setProperty('text', 'Long lyric ' * 20)
app.processEvents()
assert item.property('overflow') > 0

def progress(position, duration):
    item.setProperty('timing', {'start': 10, 'end': 10 + duration, 'position': 10 + position})
    app.processEvents()
    return item.property('scrollProgress')

for duration, finish in [(1, .6), (4, 2.8), (10, 7)]:
    assert progress(0, duration) == 0
    assert 0 < progress(duration * .4, duration) < 1
    assert abs(progress(finish, duration) - 1) < 1e-8
    assert progress(duration, duration) == 1
    # Seeking backward recomputes instead of leaving the end pinned.
    assert progress(0, duration) == 0
assert 0 <= progress(1, 0) <= 1
print('LyricTicker: early finish, end hold, short lines and seeking passed')
