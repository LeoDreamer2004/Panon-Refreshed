"""XDG paths, independent of shell configuration and installation location."""
import os
from pathlib import Path


def xdg_path(variable, fallback):
    value = os.environ.get(variable, "")
    return Path(value) if value and Path(value).is_absolute() else Path.home() / fallback


def cache_home():
    return xdg_path("XDG_CACHE_HOME", ".cache")


def config_home():
    return xdg_path("XDG_CONFIG_HOME", ".config")
