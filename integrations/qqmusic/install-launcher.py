import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from install_common import install

if __name__ == "__main__":
    install("qqmusic", __file__)
