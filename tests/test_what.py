import importlib.machinery
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("what_module", str(ROOT / "what"))
spec = importlib.util.spec_from_loader(loader.name, loader)
what = importlib.util.module_from_spec(spec)
loader.exec_module(what)


class WhatUxTest(unittest.TestCase):
    def test_pentest_profile_adds_security_focused_guidance(self):
        cfg = dict(what.DEFAULTS)
        cfg["profile"] = "pentest"
        cfg["custom_instruction"] = "优先给下一步命令"

        system, prompt = what.build_prompt(
            "nmap -sV 10.0.0.1",
            "0",
            "80/tcp open http Apache httpd 2.4.49",
            cfg=cfg,
        )

        self.assertIn("授权渗透测试", system)
        self.assertIn("CTF", system)
        self.assertIn("下一步枚举", system)
        self.assertIn("优先给下一步命令", prompt)

    def test_default_prompt_uses_full_output_without_smart_extraction(self):
        cfg = dict(what.DEFAULTS)
        output = "\n".join(f"line-{i}" for i in range(700))

        _system, prompt = what.build_prompt(
            "dirsearch -u http://target",
            "0",
            output,
            cfg=cfg,
        )

        self.assertIn("line-0", prompt)
        self.assertIn("line-350", prompt)
        self.assertIn("line-699", prompt)
        self.assertNotIn("跳过", prompt)

    def test_smart_mode_still_uses_intelligent_extraction(self):
        cfg = dict(what.DEFAULTS)
        output = "\n".join(f"line-{i}" for i in range(700))

        _system, prompt = what.build_prompt(
            "long-command",
            "0",
            output,
            cfg=cfg,
            use_smart=True,
        )

        self.assertIn("跳过", prompt)

    def test_truncate_output_keeps_head_and_tail(self):
        output = "A" * 40 + "B" * 40 + "C" * 40

        truncated = what.truncate_output(output, 80)

        self.assertTrue(truncated.startswith("A" * 20))
        self.assertTrue(truncated.endswith("C" * 20))
        self.assertIn("中间超出", truncated)
        self.assertLessEqual(len(truncated), 80)

    def test_prepare_output_reports_full_mode_metadata(self):
        cfg = dict(what.DEFAULTS)
        output, summary, meta = what.prepare_output("hello", cfg, use_smart=False)

        self.assertEqual(output, "hello")
        self.assertIsNone(summary)
        self.assertEqual(meta["mode"], "full")
        self.assertEqual(meta["original_chars"], 5)
        self.assertEqual(meta["sent_chars"], 5)

    def test_prepare_output_reports_truncated_mode_metadata(self):
        cfg = dict(what.DEFAULTS)
        cfg["max_output_chars"] = "80"
        output, summary, meta = what.prepare_output("A" * 120, cfg, use_smart=False)

        self.assertIsNone(summary)
        self.assertEqual(meta["mode"], "truncated")
        self.assertEqual(meta["original_chars"], 120)
        self.assertLessEqual(meta["sent_chars"], 80)
        self.assertIn("中间超出", output)

    def test_build_prompt_uses_structured_sections_and_answer_requirements(self):
        cfg = dict(what.DEFAULTS)
        _system, prompt = what.build_prompt(
            "curl -I http://target",
            "0",
            "HTTP/1.1 200 OK",
            cfg=cfg,
        )

        self.assertIn("上下文:", prompt)
        self.assertIn("- 命令: `curl -I http://target`", prompt)
        self.assertIn("- 退出码: 0", prompt)
        self.assertIn("- 结果类型: 成功", prompt)
        self.assertIn("- 输出处理: 完整输出", prompt)
        self.assertIn("命令输出:", prompt)
        self.assertIn("```text", prompt)
        self.assertIn("请按以下要求回答:", prompt)
        self.assertIn("先用一句话说明结论", prompt)
        self.assertIn("列出关键发现", prompt)
        self.assertIn("给出下一步建议", prompt)

    def test_custom_instruction_only_appears_in_user_prompt(self):
        cfg = dict(what.DEFAULTS)
        cfg["custom_instruction"] = "只给命令"

        system, prompt = what.build_prompt("id", "0", "uid=0(root)", cfg=cfg)

        self.assertNotIn("只给命令", system)
        self.assertEqual(prompt.count("只给命令"), 1)
        self.assertIn("用户偏好: 只给命令", prompt)

    def test_pentest_prompt_requests_authorized_next_commands(self):
        cfg = dict(what.DEFAULTS)
        cfg["profile"] = "pentest"

        _system, prompt = what.build_prompt(
            "nmap -sV 10.0.0.1",
            "0",
            "80/tcp open http Apache httpd 2.4.49",
            cfg=cfg,
        )

        self.assertIn("下一步枚举/验证命令", prompt)
        self.assertIn("仅限授权环境", prompt)

    def test_get_last_command_info_warns_when_session_log_does_not_grow(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            (tmpdir / "last_cmd").write_text("ls-l")
            (tmpdir / "last_exit").write_text("127")
            (tmpdir / "output_start").write_text("12")
            (tmpdir / "output_end").write_text("12")
            (tmpdir / "session.log").write_bytes(b"old contents")

            old_paths = (
                what.CONFIG_DIR,
                what.SESSION_LOG,
                what.LAST_CMD_FILE,
                what.LAST_EXIT_FILE,
                what.OUTPUT_START_FILE,
                what.OUTPUT_END_FILE,
            )
            try:
                what.CONFIG_DIR = str(tmpdir)
                what.SESSION_LOG = str(tmpdir / "session.log")
                what.LAST_CMD_FILE = str(tmpdir / "last_cmd")
                what.LAST_EXIT_FILE = str(tmpdir / "last_exit")
                what.OUTPUT_START_FILE = str(tmpdir / "output_start")
                what.OUTPUT_END_FILE = str(tmpdir / "output_end")

                cmd, exit_code, output = what.get_last_command_info()
            finally:
                (
                    what.CONFIG_DIR,
                    what.SESSION_LOG,
                    what.LAST_CMD_FILE,
                    what.LAST_EXIT_FILE,
                    what.OUTPUT_START_FILE,
                    what.OUTPUT_END_FILE,
                ) = old_paths

            self.assertEqual(cmd, "ls-l")
            self.assertEqual(exit_code, "127")
            self.assertIn("session.log 未增长", output)

    def test_parse_args_defaults_to_markdown_nonstream(self):
        args = what.parse_args([])

        self.assertFalse(args.stream)
        self.assertFalse(args.plain)

    def test_parse_args_supports_stream_and_plain(self):
        args = what.parse_args(["--stream", "--plain"])

        self.assertTrue(args.stream)
        self.assertTrue(args.plain)


if __name__ == "__main__":
    unittest.main()
