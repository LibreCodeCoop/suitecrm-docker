"""Runtime compatibility, Compose topology, and safe-entrypoint regression tests."""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "suitecrm_compat", ROOT / "scripts/check-runtime-compatibility.py")
compat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compat)


class CompatibilityTests(unittest.TestCase):
    PIN = "a" * 64

    def dockerfile(self, php):
        return f"FROM php:{php}-apache@sha256:{self.PIN}\n"

    def test_suitecrm_810_allows_patched_php_83(self):
        self.assertIsNone(compat.check_versions("v8.10.2", self.dockerfile("8.3.36")))

    def test_suitecrm_810_allows_php_84(self):
        self.assertIsNone(compat.check_versions("v8.10.2", self.dockerfile("8.4.14")))

    def test_php_85_is_rejected_even_if_docker_builds(self):
        self.assertIn("not listed", compat.check_versions(
            "v8.10.2", self.dockerfile("8.5.0")))

    def test_unknown_suitecrm_series_fails_closed(self):
        self.assertIn("No reviewed", compat.check_versions(
            "v8.11.0", self.dockerfile("8.3.36")))

    def test_unpinned_php_is_rejected(self):
        self.assertIn("pin", compat.check_versions(
            "v8.10.2", "FROM php:8.3-apache\n"))

    def test_real_dockerfile_uses_supported_php(self):
        self.assertIsNone(compat.check_versions(
            (ROOT / "SUITECRM_VERSION").read_text(),
            (ROOT / ".docker/php/Dockerfile").read_text()))


class ComposeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        env = os.environ.copy()
        env["MYSQL_ROOT_PASSWORD"] = "synthetic-only"
        env["MYSQL_PASSWORD"] = "synthetic-only"
        completed = subprocess.run(
            ["docker", "compose", "--profile", "background", "--profile", "dev-db",
             "config", "--format", "json"],
            cwd=ROOT, env=env, text=True, capture_output=True, check=False, timeout=15,
        )
        if completed.returncode:
            raise AssertionError("Invalid Docker Compose configuration: " +
                                 completed.stderr)
        cls.services = json.loads(completed.stdout)["services"]

    def test_production_default_never_starts_new_database(self):
        self.assertIn("dev-db", self.services["mysql"]["profiles"])
        self.assertNotIn("mysql", self.services["php"].get("depends_on", {}))
        self.assertNotIn("ports", self.services["mysql"])

    def test_background_uses_same_published_image_and_volume(self):
        web = self.services["php"]
        for name in ("messenger", "scheduler"):
            service = self.services[name]
            self.assertIn("background", service["profiles"])
            self.assertEqual(service["image"], web["image"])
            self.assertEqual(service["user"], "www-data")
            self.assertEqual(service["volumes"][0]["target"], "/var/www/html")
            self.assertEqual(service["volumes"][0]["source"],
                             web["volumes"][0]["source"])
            self.assertNotIn("build", service)
        self.assertNotIn("build", web)

    def test_messenger_consumes_only_internal_async(self):
        args = self.services["messenger"]["command"]
        self.assertIn("messenger:consume", args)
        self.assertIn("internal-async", args)
        self.assertIn("--time-limit=3600", args)
        self.assertIn("--memory-limit=256M", args)

    def test_scheduler_uses_modern_command_every_minute(self):
        command = " ".join(self.services["scheduler"]["command"])
        self.assertIn("schedulers:run", command)
        self.assertIn("sleep 60", command)
        self.assertNotIn("legacy/cron.php", command)

    def test_explicit_build_override_is_available_for_development(self):
        env = os.environ.copy()
        env["MYSQL_ROOT_PASSWORD"] = "synthetic-only"
        env["MYSQL_PASSWORD"] = "synthetic-only"
        result = subprocess.run(
            ["docker", "compose", "-f", "docker-compose.yml",
             "-f", "docker-compose.build.yml", "--profile", "background",
             "config", "--format", "json"],
            cwd=ROOT, env=env, text=True, capture_output=True, check=True, timeout=15,
        )
        config = json.loads(result.stdout)["services"]
        self.assertIn("build", config["php"])
        self.assertIn("build", config["messenger"])
        self.assertIn("build", config["scheduler"])


class EntrypointSafetyTests(unittest.TestCase):
    def test_no_implicit_mutating_sql_during_container_startup(self):
        entrypoint = (ROOT / ".docker/php/scripts/entrypoint.sh").read_text()
        # Never run DDL/DML during web, messenger or scheduler container startup.
        # In particular, the unmerged PR #3 must not bypass a migration workflow.
        for operation in ("doctrine:query:sql", "dbal:run-sql",
                          "DROP TRIGGER", "UPDATE emails", "DELETE FROM"):
            self.assertNotIn(operation, entrypoint)


if __name__ == "__main__":
    unittest.main()
