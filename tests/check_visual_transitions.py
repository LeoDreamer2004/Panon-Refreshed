"""Offscreen QML loading and cover transition regression checks (PySide6)."""
import os
import tempfile
from pathlib import Path

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QImage, QColor
from PySide6.QtQml import QQmlEngine, QQmlComponent
from PySide6.QtTest import QTest

app = QGuiApplication([])
engine = QQmlEngine()
engine.globalObject().setProperty('i18nd', engine.evaluate('(function(d,t){return t;})'))
root = Path(__file__).resolve().parents[1] / 'contents/ui'
components, objects = [], []
for name in ('CoverTransition.qml', 'RadialAlbum.qml', 'DesktopLyrics.qml', 'DesktopView.qml'):
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(root / name)))
    components.append(component)
    item = component.create()
    assert item is not None, '\n'.join(error.toString() for error in component.errors())
    objects.append(item)
    print(name, 'created')

cover = objects[0]
cover.setProperty('width', 160)
cover.setProperty('height', 160)
with tempfile.TemporaryDirectory() as folder:
    images = []
    for color in ('red', 'blue'):
        path = Path(folder) / f'{color}.png'
        image = QImage(200, 100, QImage.Format_ARGB32)
        image.fill(QColor(color))
        assert image.save(str(path))
        images.append(QUrl.fromLocalFile(str(path)))
    for i, source in enumerate(images):
        cover.setProperty('source', source)
        for _ in range(100):
            QTest.qWait(10)
            if cover.property('front') == i:
                break
        assert cover.property('front') == i
        assert cover.property('ready')
    # A transient missing URL must not discard the decoded cover.
    cover.setProperty('source', QUrl())
    QTest.qWait(20)
    assert cover.property('front') == 1
    # Returning to a previously decoded cover must also transition correctly.
    cover.setProperty('source', images[0])
    QTest.qWait(50)
    assert cover.property('front') == 0
print('Cover buffers: load, switch, transient gap and rapid return passed')
