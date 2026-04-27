import sys
from PIL import Image
image = Image.open(sys.argv[1])
raise SystemExit(0 if image.size == (1366, 768) else 1)
