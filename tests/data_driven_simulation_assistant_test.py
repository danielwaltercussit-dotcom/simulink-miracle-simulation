import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = REPO_ROOT / "scripts" / "ml"
FIXTURES = REPO_ROOT / "tests" / "fixtures" / "data_driven_simulation_assistant"
P7_TARGET_SKILLS = [
    "simulink-modeling-assistant",
    "ai-in-loop",
    "small-signal-modal-analysis",
    "power-electronics-tuning",
    "baseline-regression",
]

sys.path.insert(0, str(SCRIPTS))

from simulation_assistant_lib import load_jsonl, validate_record  # noqa: E402


class DataDrivenSimulationAssistantTest(unittest.TestCase):
    def test_fixture_dataset_schema(self):
        records = load_jsonl(FIXTURES / "dataset.jsonl")
        self.assertGreaterEqual(len(records), 6)
        for record in records:
            self.assertEqual(validate_record(record), [])
        self.assertTrue(any(".slx" in record["text_summary"] for record in records))
        self.assertTrue(any(".mat" in record["text_summary"] for record in records))

    def test_dataset_builder_scans_text_only(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "reports").mkdir()
            (root / "reports" / "case.md").write_text(
                "S5 report: duplicate timestamps and zero duration create a degenerate time axis. "
                "The text mentions candidate.slx and result.mat as references only.",
                encoding="utf-8",
            )
            (root / "reports" / "binary.slx").write_bytes(b"not text")
            output = root / "build" / "ml" / "dataset.jsonl"
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "build_simulation_experience_dataset.py"),
                    "--repo-root",
                    str(root),
                    "--output",
                    str(output),
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=True,
            )
            summary = json.loads(result.stdout)
            self.assertEqual(summary["written_records"], 1)
            records = load_jsonl(output)
            self.assertEqual(records[0]["labels"], ["degenerate_time_axis"])
            self.assertNotIn("binary.slx", records[0]["source_path"])

    def test_retrieval_fixtures_return_expected_labels(self):
        for fixture_path in sorted(FIXTURES.glob("*.json")):
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "suggest_simulation_diagnosis.py"),
                    "--fixture",
                    str(fixture_path),
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=True,
            )
            payload = json.loads(result.stdout)
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
            labels = [candidate["label"] for candidate in payload["candidates"]]
            self.assertIn(fixture["expected_labels"][0], labels[:3], fixture_path.name)
            for gate in fixture["required_gate_substrings"]:
                self.assertIn(gate, "\n".join(payload["required_gates"]), fixture_path.name)
            serialized = json.dumps(payload)
            self.assertNotIn("s6_authorized", serialized)
            self.assertNotIn("model_accepted", serialized)

    def test_evaluation_harness_passes_offline(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "evaluate_simulation_assistant.py"),
                    "--fixtures",
                    str(FIXTURES),
                    "--output-dir",
                    str(Path(temp_dir) / "reports"),
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=True,
            )
            payload = json.loads(result.stdout)
            self.assertEqual(payload["fixture_count"], 5)
            self.assertEqual(payload["top3_label_hit"], 1.0)
            self.assertEqual(payload["forbidden_action_violations"], 0)
            self.assertEqual(payload["missing_gate_violations"], 0)

    def test_cpu_neural_classifier_prototype_compares_against_baseline(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            model_dir = Path(temp_dir) / "models"
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "train_failure_signature_classifier.py"),
                    "--dataset",
                    str(FIXTURES / "dataset.jsonl"),
                    "--fixtures",
                    str(FIXTURES),
                    "--model-dir",
                    str(model_dir),
                    "--epochs",
                    "500",
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=True,
            )
            payload = json.loads(result.stdout)
            self.assertEqual(payload["model"]["type"], "hashed_bow_numpy_mlp")
            self.assertEqual(payload["classifier"]["top3_label_hit"], 1.0)
            self.assertGreaterEqual(payload["classifier"]["confidence_gain_cases"], 1)
            self.assertEqual(payload["forbidden_action_violations"], 0)
            self.assertEqual(payload["missing_gate_violations"], 0)
            self.assertTrue((model_dir / "failure_signature_classifier_model.json").exists())
            for case in payload["cases"]:
                self.assertEqual(case["classifier_result"]["status"], "advisory_needs_gate")
                self.assertTrue(case["classifier_result"]["required_gates"])

    def test_experiment_suggestion_mode_respects_p6_acceptance(self):
        cases = [
            (
                "ambient_masked.json",
                ["source_isolation", "evidence_separation"],
                ["repeated same-amplitude ringdown"],
            ),
            (
                "memory_unbounded.json",
                ["bounded_memory_probe", "pid", "slope"],
                [],
            ),
            (
                "frequency_coincidence.json",
                ["sensitivity", "participation", "source_disable"],
                ["gain change", "parameter tuning"],
            ),
        ]
        for fixture_name, expected_terms, rejected_terms in cases:
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "suggest_simulation_diagnosis.py"),
                    "--fixture",
                    str(FIXTURES / fixture_name),
                    "--suggest-experiment",
                    "--evidence-gap",
                    "missing deterministic gate review",
                    "--max-runtime-minutes",
                    "9",
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=True,
            )
            payload = json.loads(result.stdout)
            suggestion = payload["experiment_suggestion"]
            proposed = json.dumps(suggestion["proposed_experiment"], sort_keys=True).lower()
            self.assertFalse(suggestion["auto_launch"])
            self.assertLessEqual(suggestion["resource_budget"]["max_runtime_minutes"], 9)
            self.assertTrue(suggestion["stop_conditions"])
            self.assertTrue(suggestion["required_gates"])
            for term in expected_terms:
                self.assertIn(term, proposed, fixture_name)
            for term in rejected_terms:
                self.assertNotIn(term, proposed, fixture_name)

    def test_p7_skill_routing_notes_keep_assistant_advisory(self):
        forbidden_phrases = [
            "assistant can authorize",
            "assistant authorizes",
            "data-driven output authorizes",
            "data-driven assistant authorizes",
        ]
        for skill_name in P7_TARGET_SKILLS:
            path = REPO_ROOT / ".agents" / "skills" / skill_name / "SKILL.md"
            text = path.read_text(encoding="utf-8").lower()
            self.assertIn("data-driven-simulation-assistant", text, skill_name)
            self.assertIn("candidate retrieval", text, skill_name)
            self.assertIn("deterministic", text, skill_name)
            for phrase in forbidden_phrases:
                self.assertNotIn(phrase, text, skill_name)


if __name__ == "__main__":
    unittest.main()
