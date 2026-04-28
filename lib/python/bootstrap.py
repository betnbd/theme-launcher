import json
import sys
from pathlib import Path

from theme_metadata import collect_theme_metadata, read_text


metadata = collect_theme_metadata(
    Path(sys.argv[1]),
    Path(sys.argv[2]),
    Path(sys.argv[3]),
    Path(sys.argv[4]),
    Path(sys.argv[5]),
    Path(sys.argv[6]),
    Path(sys.argv[7]),
)
default_theme = read_text(Path(sys.argv[8]))
current_theme = read_text(Path(sys.argv[6]))

print(
    json.dumps(
        {
            "metadata": metadata,
            "current": current_theme,
            "default": default_theme,
        },
        separators=(",", ":"),
    )
)
