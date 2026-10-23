"""End-to-end shell-script tests with fake Docker and downloads; no real side effects."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

DOCKER_STUB = """#!/usr/bin/env python3
import os
from pathlib import Path
import sys
argv = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a", encoding="utf-8") as out:
    out.write("docker " + " ".join(argv) + "\\n")
if "suitecrm:version" in argv:
    done = Path(os.environ["TEST_UPGRADED"]).exists()
    print(os.environ["TARGET_VERSION"] if done else os.environ["CURRENT_VERSION"])
elif "suitecrm:app:upgrade-finalize" in argv:
    if os.environ.get("FAIL_FINALIZE") == "1":
        sys.exit(26)
    Path(os.environ["TEST_UPGRADED"]).write_text("done", encoding="utf-8")
elif "suitecrm:app:upgrade" in argv and os.environ.get("FAIL_UPGRADE") == "1":
    sys.exit(27)
elif "sh" in argv and "-c" in argv and os.environ.get("ALLOW_PROD") == "0":
    sys.exit(28)
elif "ps" in argv:
    print("fake-running-container")
"""
CURL_STUB = """#!/usr/bin/env python3
import os
from pathlib import Path
import sys
argv = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a", encoding="utf-8") as out:
    out.write("curl " + " ".join(argv) + "\\n")
Path(argv[argv.index("--output") + 1]).write_bytes(b"synthetic-not-a-real-package")
"""
UNZIP_STUB = """#!/usr/bin/env python3
import os
from pathlib import Path
import sys
argv = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a", encoding="utf-8") as out:
    out.write("unzip " + " ".join(argv) + "\\n")
sys.exit(0 if Path(argv[-1]).is_file() else 17)
"""


class ShellScriptsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.project = self.dir / "project"
        (self.project / "scripts").mkdir(parents=True)
        for relative in ("install.sh", "scripts/upgrade-suitecrm.sh", "SUITECRM_VERSION"):
            shutil.copy2(ROOT / relative, self.project / relative)
        self.calls = self.dir / "commands.log"
        self.calls.write_text("", encoding="utf-8")
        self.bin = self.dir / "fake-bin"
        self.bin.mkdir()
        for name, body in (("docker", DOCKER_STUB), ("curl", CURL_STUB), ("unzip", UNZIP_STUB)):
            script = self.bin / name
            script.write_text(body, encoding="utf-8")
            script.chmod(0o755)
        self.env = dict(os.environ)
        self.env.update({
            "PATH": str(self.bin) + os.pathsep + self.env["PATH"],
            "TEST_CALLS": str(self.calls),
            "TEST_UPGRADED": str(self.dir / "upgraded"),
            "CURRENT_VERSION": "8.10.1",
            "TARGET_VERSION": "8.10.2",
        })

    def run_script(self, path, *args):
        return subprocess.run(
            ["bash", str(self.project / path), *args],
            cwd=self.project, env=self.env, text=True, capture_output=True,
            timeout=8, check=False,
        )

    def commands(self):
        return self.calls.read_text(encoding="utf-8")

    def test_upgrade_requires_verified_backup(self):
        result = self.run_script("scripts/upgrade-suitecrm.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("verified file and database backups", result.stderr)
        self.assertEqual(self.commands(), "")

    def test_upgrade_rejects_invalid_version_without_side_effects(self):
        (self.project / "SUITECRM_VERSION").write_text("v8.10.2;invalid")
        result = self.run_script("scripts/upgrade-suitecrm.sh", "--backup-confirmed")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_upgrade_uses_real_cli_and_checks_result(self):
        result = self.run_script("scripts/upgrade-suitecrm.sh", "--backup-confirmed")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        commands = self.commands()
        self.assertEqual(commands.count("suitecrm:version"), 2)
        self.assertIn("suitecrm:app:upgrade --no-interaction", commands)
        self.assertIn("suitecrm:app:upgrade-finalize --no-interaction", commands)
        self.assertIn("docker compose restart php", commands)
        self.assertNotIn("app:version:status", commands)
        self.assertIn("Installed application version: 8.10.2", result.stdout)
        self.assertIn("--user www-data php php bin/console suitecrm:", commands)

    def test_upgrade_of_installed_version_does_not_mutate(self):
        self.env["CURRENT_VERSION"] = "8.10.2"
        result = self.run_script("scripts/upgrade-suitecrm.sh", "--backup-confirmed")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Already at target version", result.stdout)
        self.assertNotIn("curl ", self.commands())
        self.assertNotIn("upgrade-finalize", self.commands())
        self.assertNotIn("docker compose restart", self.commands())

    def test_failed_upgrade_never_reports_success(self):
        self.env["FAIL_UPGRADE"] = "1"
        result = self.run_script("scripts/upgrade-suitecrm.sh", "--backup-confirmed")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("upgrade-finalize", self.commands())
        self.assertNotIn("docker compose restart", self.commands())

    def test_failed_finalization_does_not_restart(self):
        self.env["FAIL_FINALIZE"] = "1"
        result = self.run_script("scripts/upgrade-suitecrm.sh", "--backup-confirmed")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("docker compose restart", self.commands())

    def test_upgrade_refuses_non_production_target(self):
        self.env["ALLOW_PROD"] = "0"
        result = self.run_script("scripts/upgrade-suitecrm.sh", "--backup-confirmed")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("curl ", self.commands())

    def test_install_requires_credentials_without_running_docker(self):
        (self.project / ".env").write_text("MYSQL_ROOT_PASSWORD=\nMYSQL_PASSWORD=\n")
        result = self.run_script("install.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_install_starts_database_explicitly_and_workers_after_setup(self):
        (self.project / ".env").write_text("MYSQL_ROOT_PASSWORD=test\nMYSQL_PASSWORD=test\n")
        result = self.run_script("install.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        commands = self.commands()
        self.assertIn("docker compose --profile dev-db up -d --wait mysql", commands)
        self.assertIn("docker compose up -d php", commands)
        self.assertIn("docker compose exec -u www-data php php bin/console suitecrm:app:install", commands)
        self.assertIn("docker compose --profile background up -d messenger scheduler", commands)
        self.assertNotIn("app:version:status", commands)


if __name__ == "__main__":
    unittest.main()
