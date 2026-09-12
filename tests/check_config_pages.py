"""Actual KDE-style QML creation test; requires PySide6 and Plasma QML modules.

Run with QT_QPA_PLATFORM=offscreen python3 tests/check_config_pages.py.
Kept separate from the dependency-light backend CI suite.
"""
import os
import json
from pathlib import Path
import sys

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_CONTROLS_STYLE', 'org.kde.desktop')

from PySide6.QtCore import QUrl, QMetaObject, Q_ARG, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

app = QGuiApplication(sys.argv)
engine = QQmlEngine()
engine.globalObject().setProperty('i18nd', engine.evaluate('(function(domain, text) { return text; })'))
engine.globalObject().setProperty('i18ndc', engine.evaluate('(function(domain, context, text) { return text; })'))
root = Path(__file__).resolve().parents[1] / 'contents/ui/config'
objects = []
components = []
for name in ('ConfigGeneral.qml', 'ConfigServices.qml', 'ConfigIntegrations.qml'):
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(root / name)))
    components.append(component)
    if component.isError():
        raise RuntimeError('\n'.join(error.toString() for error in component.errors()))
    item = component.create()
    if item is None:
        raise RuntimeError('\n'.join(error.toString() for error in component.errors()))
    objects.append(item)
    app.processEvents()
    if name == 'ConfigServices.qml':
        item.setProperty('dependencyCheckStarted', True)
        for checks in ([dict(name='numpy', required=True, ok=True)],
                       [dict(name='numpy', required=True, ok=False, error='missing library'),
                        dict(name='pykakasi', required=False, ok=False)]):
            report = json.dumps(dict(python='/usr/bin/python3', version='3.14', checks=checks))
            assert QMetaObject.invokeMethod(item, 'showDoctorResult', Qt.DirectConnection,
                                           Q_ARG('QVariant', report), Q_ARG('QVariant', ''))
            app.processEvents()
            assert not item.property('dependencyError')
        assert QMetaObject.invokeMethod(item, 'showDoctorResult', Qt.DirectConnection,
                                       Q_ARG('QVariant', 'not JSON'), Q_ARG('QVariant', 'interpreter not found'))
        assert item.property('dependencyError') == 'interpreter not found'
        app.processEvents()
    print(f'{name}: created successfully')
for item in objects:
    item.deleteLater()
app.processEvents()
