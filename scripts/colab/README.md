# Colab Automation Suite

Modular notebooks for offloading compute from local development to Google Colab's free GPU/CPU.

## Quick Start (in any Colab notebook)

```python
# Cell 1: Setup environment
!bash scripts/colab/setup_colab.sh

# Cell 2: Import the runner
import sys; sys.path.insert(0, 'scripts/colab')
from godot_runner import GodotRunner

# Cell 3: Run any operation
runner = GodotRunner(project_dir='CATSINO.CASINO/godot')
result = runner.validate()
print(f"Parse errors: {len(result.errors)}")
```

## Architecture

```
scripts/colab/
  godot_runner.py       # Reusable Python module - import from any notebook
  setup_colab.sh        # One-click environment setup (Godot + deps)
  01_validate.ipynb     # Parse check + smoke test + gdUnit4
  02_export.ipynb       # Multi-platform export (Web + Win + Linux + macOS)
  03_bake.ipynb         # Asset pipeline (GLB optimize, texture atlases)
  04_osm.ipynb          # OSM city data fetch + bake
  05_release.ipynb      # Full CI pipeline (validate -> export -> package -> release)
  README.md             # This file
```

## Notebooks

| # | Notebook | Does | ~Runtime |
|---|----------|------|----------|
| 01 | `validate_and_test` | Parse check + boot smoke + gdUnit4 | 3 min |
| 02 | `export_all` | Web + Windows + Linux + macOS export | 40 min |
| 03 | `bake_assets` | GLB optimization, texture atlas baking | 10 min |
| 04 | `process_osm` | Fetch + bake OSM city data from OpenStreetMap | 5 min |
| 05 | `full_release` | Master pipeline: Validate -> Smoke -> Test -> Export -> Package | 45 min |

## CLI Usage (local or CI)

```bash
# Validate
python scripts/colab/godot_runner.py --project godot validate

# Export all platforms
python scripts/colab/godot_runner.py --project godot export-all

# Full pipeline (validate + export + package)
python scripts/colab/godot_runner.py --project godot full
```

## godot_runner.py API

```python
from godot_runner import GodotRunner, RunResult

runner = GodotRunner(
    project_dir="/content/CATSINO.CASINO/godot",  # path to project.godot
    godot_binary="godot",                          # or full path
    verbose=True                                    # print live output
)

# All return RunResult (see dataclass below)
result: RunResult = runner.validate()       # headless editor import
result: RunResult = runner.run_tests()      # gdUnit4
result: RunResult = runner.boot_smoke()     # boot critical autoloads
result: RunResult = runner.export_web()     # HTML5 export
result: RunResult = runner.export_windows() # .exe export
result: RunResult = runner.export_linux()   # Linux binary
result: RunResult = runner.export_macos()   # macOS .zip
results: dict    = runner.export_all()      # all platforms
zip_path: str    = runner.package_release() # zip everything
result: RunResult = runner.bake_glb_assets()# import .glb files
```

### RunResult fields

```
.success: bool           # True if zero errors and exit=0
.command: str             # Full command that ran
.stdout: str              # Captured stdout
.stderr: str              # Captured stderr
.duration_seconds: float  # Wall clock time
.artifacts: List[str]     # Output file paths
.errors: List[str]        # Parsed ERROR lines
.warnings: List[str]      # Parsed WARNING lines
.exit_code: int           # Process exit code
```
