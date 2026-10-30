"""実行例: /usr/bin/python3 -m unittest discover -s tests -v (tomlkit が必要)。"""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import tomlkit


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("codex_config", ROOT / "lib/codex-config.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CodexConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / "users/alice"
        self.codex = self.base / "custom-codex"
        self.codex.mkdir()
        self.config = self.codex / "config.toml"

    def test_new_config_uses_selected_home_and_is_idempotent(self):
        MODULE.configure(self.codex, self.home)
        first = self.config.read_bytes()
        data = tomlkit.parse(first.decode())
        self.assertEqual(data["sandbox_mode"], "workspace-write")
        self.assertEqual(data["approval_policy"], "on-request")
        self.assertEqual(data["approvals_reviewer"], "auto_review")
        self.assertTrue(data["sandbox_workspace_write"]["network_access"])
        self.assertEqual(data["sandbox_workspace_write"]["writable_roots"], [
            str(self.home / ".local"), str(self.home / ".cache"),
        ])
        self.assertEqual(data["mcp_servers"]["context7"]["command"], "npx")
        self.assertEqual(data["mcp_servers"]["context7"]["args"],
                         ["-y", "@upstash/context7-mcp"])
        MODULE.configure(self.codex, self.home)
        self.assertEqual(self.config.read_bytes(), first)
        self.assertFalse((self.codex / "config.toml.bak").exists())

    def test_existing_settings_comments_roots_and_backup_survive(self):
        original = '''# personal settings
model = "custom-model"
approval_policy = "never"
approvals_reviewer = "user"
[mcp_servers.example]
command = "example"
[mcp_servers.context7]
command = "old-context7"
env = { "CONTEXT7_API_KEY" = "secret" }
[sandbox_workspace_write]
network_access = false
writable_roots = [
    "/srv/dev", # custom root
]
'''
        self.config.write_text(original)
        MODULE.configure(self.codex, self.home)
        updated = self.config.read_text()
        data = tomlkit.parse(updated)
        self.assertEqual(data["model"], "custom-model")
        self.assertEqual(data["approvals_reviewer"], "auto_review")
        self.assertEqual(data["mcp_servers"]["example"]["command"], "example")
        self.assertEqual(data["mcp_servers"]["context7"]["command"], "npx")
        self.assertEqual(data["mcp_servers"]["context7"]["env"]["CONTEXT7_API_KEY"], "secret")
        self.assertIn("# personal settings", updated)
        self.assertIn("# custom root", updated)
        self.assertIn("/srv/dev", data["sandbox_workspace_write"]["writable_roots"])
        MODULE.configure(self.codex, self.home)
        self.assertEqual(self.config.read_text(), updated)
        self.assertEqual((self.codex / "config.toml.bak").read_text(), original)

    def test_invalid_input_is_not_overwritten(self):
        for original in ('model = [', '[sandbox_workspace_write]\nwritable_roots = "bad"\n'):
            with self.subTest(original=original):
                self.config.write_text(original)
                with self.assertRaises((ValueError, TypeError)):
                    MODULE.configure(self.codex, self.home)
                self.assertEqual(self.config.read_text(), original)
                self.assertFalse((self.codex / "config.toml.bak").exists())

    def test_shell_step_resolves_user_and_passes_rtk_destination(self):
        binaries = self.base / "bin"
        binaries.mkdir()
        # スタブでアカウント DB と RTK を隔離し、sudo / 実ユーザーの設定には触れない。
        scripts = {
            "getent": '#!/bin/sh\n[ "$1" = passwd ] && [ "$2" = alice ] || exit 1\nprintf "alice:x:1234:1234::%s:/bin/sh\\n" "$TEST_USER_HOME"\n',
            "rtk": '#!/bin/sh\n[ "$*" = "init --codex --global" ] || exit 1\n[ "$HOME" = "$TEST_USER_HOME" ] || exit 1\n[ "$CODEX_HOME" = "$TEST_CODEX_DIR" ] || exit 1\nprintf "rtk initialized\\n" > "$CODEX_HOME/rtk-called"\n',
        }
        for name, content in scripts.items():
            path = binaries / name
            path.write_text(content)
            path.chmod(0o755)
        override = self.codex / "AGENTS.override.md"
        override.write_text("Keep my instructions.\n")
        skills = self.home / ".agents/skills"
        (skills / "my-own-skill").mkdir(parents=True)
        (skills / "my-own-skill/SKILL.md").write_text("mine\n")
        (skills / "git-workflow").mkdir()
        (skills / "git-workflow/stale.md").write_text("old\n")
        env = dict(os.environ, USER="alice", HOME=str(self.base / "wrong-home"),
                   CODEX_HOME=str(self.codex), TEST_USER_HOME=str(self.home),
                   TEST_CODEX_DIR=str(self.codex), PATH=f"{binaries}:/usr/bin:/bin")
        for _ in range(2):
            result = subprocess.run([str(ROOT / "setup.sh"), "codex-config"], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.codex / "rtk-called").exists())
        self.assertEqual(override.read_text().count(f"@{self.codex}/RTK.md"), 1)
        self.assertEqual(override.with_name("AGENTS.override.md.bak").read_text(),
                         "Keep my instructions.\n")
        roots = tomlkit.parse(self.config.read_text())["sandbox_workspace_write"]["writable_roots"]
        self.assertIn(str(self.home / ".local"), roots)
        self.assertFalse((self.base / "wrong-home").exists())
        for skill in (ROOT / "agent-skills").iterdir():
            self.assertEqual((skills / skill.name / "SKILL.md").read_text(),
                             (skill / "SKILL.md").read_text())
        self.assertEqual((skills / "my-own-skill/SKILL.md").read_text(), "mine\n")
        self.assertFalse((skills / "git-workflow/stale.md").exists())


if __name__ == "__main__":
    unittest.main()
