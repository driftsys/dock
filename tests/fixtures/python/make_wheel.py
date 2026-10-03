"""Create an offline dependency wheel using only the Python standard library."""

import base64
import hashlib
from pathlib import Path
import sys
import zipfile

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
metadata = "dock_fixture-1.0.0.dist-info"
files = {
    "dock_fixture/__init__.py": b'MESSAGE = "offline dependency works"\n',
    f"{metadata}/METADATA": b"Metadata-Version: 2.1\nName: dock-fixture\nVersion: 1.0.0\n",
    f"{metadata}/WHEEL": b"Wheel-Version: 1.0\nGenerator: dock-fixture\nRoot-Is-Purelib: true\nTag: py3-none-any\n",
}
records = []
for name, content in files.items():
    digest = base64.urlsafe_b64encode(hashlib.sha256(content).digest()).rstrip(b"=")
    records.append(f"{name},sha256={digest.decode()},{len(content)}")
records.append(f"{metadata}/RECORD,,")
files[f"{metadata}/RECORD"] = ("\n".join(records) + "\n").encode()
with zipfile.ZipFile(root / "dock_fixture-1.0.0-py3-none-any.whl", "w") as wheel:
    for name, content in files.items():
        wheel.writestr(name, content)
