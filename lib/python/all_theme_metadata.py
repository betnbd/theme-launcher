import json
import sys
from pathlib import Path

from theme_metadata import collect_theme_metadata


metadata = collect_theme_metadata(
    Path(sys.argv[1]),
    Path(sys.argv[2]),
    Path(sys.argv[3]),
    Path(sys.argv[4]),
    Path(sys.argv[5]),
    Path(sys.argv[6]),
)

print(json.dumps(metadata, separators=(",", ":")))
