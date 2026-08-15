"""
godot_runner.py - Reusable headless Godot operations for Colab & CI.

Import from any notebook. Every operation returns structured RunResults.
Usage:
    from godot_runner import GodotRunner
    runner = GodotRunner(project_dir="/content/CATSINO.CASINO/godot")
    runner.validate()       # check parse errors
    runner.export_web()     # export HTML5
    runner.export_all()     # all platforms
    runner.package_release()# zip everything
"""

import os, sys, time, subprocess, zipfile
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass, field


@dataclass
class RunResult:
    """Structured result from any Godot headless operation."""
    success: bool
    command: str
    stdout: str = ""
    stderr: str = ""
    duration_seconds: float = 0.0
    artifacts: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    exit_code: int = -1


class GodotRunner:
    """Wraps all headless Godot operations with logging and structured results."""

    DEFAULT_TIMEOUT = 600
    VALIDATE_TIMEOUT = 120
    TEST_TIMEOUT = 300

    def __init__(self, project_dir, godot_binary="godot", verbose=True):
        self.project_dir = Path(project_dir).resolve()
        self.godot_binary = godot_binary
        self.verbose = verbose
        self._log(f"GodotRunner: {self.project_dir}")
        if not (self.project_dir / "project.godot").exists():
            raise FileNotFoundError(
                f"project.godot not found in {self.project_dir}"
            )

    def _log(self, msg):
        if self.verbose:
            print(f"[GodotRunner] {msg}")

    def _run(self, args, timeout=None, cwd=None):
        if timeout is None:
            timeout = self.DEFAULT_TIMEOUT
        cmd = [self.godot_binary, "--headless", "--path",
               str(self.project_dir)] + args
        self._log(f"RUN: {' '.join(cmd)}")
        start = time.time()
        try:
            proc = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout,
                cwd=cwd or str(self.project_dir)
            )
        except subprocess.TimeoutExpired:
            return RunResult(
                success=False, command=" ".join(cmd),
                stderr=f"TIMEOUT after {timeout}s",
                duration_seconds=time.time() - start, exit_code=-1
            )
        stdout = proc.stdout or ""
        stderr = proc.stderr or ""
        duration = time.time() - start
        combined = stdout + "\n" + stderr
        errors = [l.strip() for l in combined.split("\n")
                  if "ERROR:" in l or "Parse Error:" in l]
        warnings = [l.strip() for l in combined.split("\n")
                    if "WARNING:" in l]
        success = proc.returncode == 0 and len(errors) == 0
        result = RunResult(
            success=success, command=" ".join(cmd),
            stdout=stdout, stderr=stderr, duration_seconds=duration,
            errors=errors, warnings=warnings, exit_code=proc.returncode
        )
        self._log(f"  DONE in {duration:.1f}s "
                  f"(exit={proc.returncode}, errors={len(errors)})")
        return result

    # ── Public operations ──

    def validate(self):
        """Check project parses cleanly via headless editor import."""
        self._log("Validating project (headless editor import)...")
        result = self._run(["--import", "--quit"],
                           timeout=self.VALIDATE_TIMEOUT)
        if result.errors:
            self._log(f"  VALIDATION FAILED: {len(result.errors)} errors")
        else:
            self._log("  Validation passed: zero parse errors.")
        return result

    def run_tests(self, test_path="res://test"):
        """Run gdUnit4 tests. Requires gdUnit4 addon installed."""
        self._log(f"Running gdUnit4 tests: {test_path}")
        return self._run(
            ["-s", "addons/gdUnit4/bin/GdUnitCmdTool.gd",
             "--add", test_path, "--ignoreHeadlessMode"],
            timeout=self.TEST_TIMEOUT
        )

    def boot_smoke(self, script_path="res://src/dev/boot_smoke.gd",
                   timeout=120):
        """Run a smoke script that boots critical autoloads."""
        self._log(f"Boot smoke: {script_path}")
        result = self._run(["-s", script_path], timeout=timeout)
        result.success = ("PASS" in result.stdout and
                          "FAIL" not in result.stdout)
        self._log(f"  Smoke: {'PASS' if result.success else 'FAIL'}")
        return result

    def export_web(self, output_dir="../builds/html5"):
        self._log("Exporting Web (HTML5)...")
        os.makedirs(output_dir, exist_ok=True)
        out = str(Path(output_dir).resolve() / "index.html")
        result = self._run(
            ["--export-release", "Web", out],
            timeout=self.DEFAULT_TIMEOUT, cwd=str(self.project_dir)
        )
        for f in ["index.html", "index.pck", "index.wasm"]:
            p = Path(output_dir) / f
            if p.exists():
                result.artifacts.append(str(p))
        self._log(f"  Exported {len(result.artifacts)} files")
        return result

    def export_windows(self, output_dir="../builds/windows",
                       exe_name="CATSINO.exe"):
        self._log("Exporting Windows...")
        os.makedirs(output_dir, exist_ok=True)
        out = str(Path(output_dir).resolve() / exe_name)
        result = self._run(
            ["--export-release", "Windows", out],
            timeout=self.DEFAULT_TIMEOUT, cwd=str(self.project_dir)
        )
        for f in [exe_name, exe_name.replace(".exe", ".pck")]:
            p = Path(output_dir) / f
            if p.exists():
                result.artifacts.append(str(p))
        return result

    def export_linux(self, output_dir="../builds/linux",
                     bin_name="CATSINO.x86_64"):
        self._log("Exporting Linux...")
        os.makedirs(output_dir, exist_ok=True)
        out = str(Path(output_dir).resolve() / bin_name)
        result = self._run(
            ["--export-release", "Linux", out],
            timeout=self.DEFAULT_TIMEOUT, cwd=str(self.project_dir)
        )
        p = Path(output_dir) / bin_name
        if p.exists():
            result.artifacts.append(str(p))
        return result

    def export_macos(self, output_dir="../builds/macos",
                     app_name="CATSINO.zip"):
        self._log("Exporting macOS...")
        os.makedirs(output_dir, exist_ok=True)
        out = str(Path(output_dir).resolve() / app_name)
        result = self._run(
            ["--export-release", "macOS", out],
            timeout=self.DEFAULT_TIMEOUT, cwd=str(self.project_dir)
        )
        p = Path(output_dir) / app_name
        if p.exists():
            result.artifacts.append(str(p))
        return result

    def export_all(self, output_root="../builds"):
        """Run all exports. Returns dict of preset -> RunResult."""
        results = {}
        results["web"] = self.export_web(f"{output_root}/html5")
        results["windows"] = self.export_windows(f"{output_root}/windows")
        results["linux"] = self.export_linux(f"{output_root}/linux")
        results["macos"] = self.export_macos(f"{output_root}/macos")
        passed = sum(1 for r in results.values() if r.success)
        self._log(f"Export summary: {passed}/{len(results)} succeeded")
        return results

    def package_release(self, build_dir="../builds",
                        output_dir="../releases", version="0.4.0"):
        """Zip all build artifacts into a release package."""
        self._log(f"Packaging release v{version}...")
        os.makedirs(output_dir, exist_ok=True)
        zip_name = f"CATSINO_v{version}.zip"
        zip_path = Path(output_dir) / zip_name
        build_path = Path(build_dir)
        if not build_path.exists():
            self._log("  No build directory found.")
            return None
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(build_path):
                for file in files:
                    full = Path(root) / file
                    arcname = str(full.relative_to(build_path))
                    zf.write(full, arcname)
        size_mb = zip_path.stat().st_size / (1024 * 1024)
        self._log(f"  Packaged: {zip_path} ({size_mb:.1f} MB)")
        return str(zip_path)

    def bake_glb_assets(self, assets_dir="assets/models"):
        """Run Godot's GLB import pipeline."""
        self._log("Baking GLB assets...")
        result = self._run(["--import", "--quit"],
                           timeout=self.DEFAULT_TIMEOUT)
        glb_count = 0
        model_dir = self.project_dir / assets_dir
        if model_dir.exists():
            for root, dirs, files in os.walk(str(model_dir)):
                glb_count += sum(1 for f in files if f.endswith(".glb"))
        self._log(f"  Found {glb_count} .glb files")
        return result


# ─── CLI entry ────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="Godot headless runner")
    p.add_argument("--project", default=".",
                   help="Path to Godot project directory")
    p.add_argument("--godot", default="godot",
                   help="Godot binary path or name")
    p.add_argument("command", choices=[
        "validate", "test", "smoke", "export-web",
        "export-all", "full"
    ])
    args = p.parse_args()
    runner = GodotRunner(args.project, args.godot)

    if args.command == "validate":
        result = runner.validate()
    elif args.command == "test":
        result = runner.run_tests()
    elif args.command == "smoke":
        result = runner.boot_smoke()
    elif args.command == "export-web":
        result = runner.export_web()
    elif args.command == "export-all":
        results = runner.export_all()
        for name, r in results.items():
            print(f"  {name}: {'PASS' if r.success else 'FAIL'}")
    elif args.command == "full":
        print("=== VALIDATE ===")
        v = runner.validate()
        if not v.success:
            print("VALIDATION FAILED - stopping.")
            sys.exit(1)
        print("=== EXPORT ALL ===")
        results = runner.export_all()
        for name, r in results.items():
            print(f"  {name}: {'PASS' if r.success else 'FAIL'}")
        runner.package_release()

    print("Done.")
