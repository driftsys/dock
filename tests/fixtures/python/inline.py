# /// script
# requires-python = ">=3.13"
# dependencies = ["dock-fixture==1.0.0"]
# ///
import json
import sys

from dock_fixture import MESSAGE

print(json.dumps({"message": MESSAGE, "python": sys.base_prefix}))
