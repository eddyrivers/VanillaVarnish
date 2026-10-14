"""Projection safeguards that prevent incorrect hostile loot relationships."""
import unittest

from tools.build_quest_drops import used_items, project, render, validate_review_pins, notice_hash


class Table(dict):
    def __missing__(self, key):
        return None


class QuestDropGeneratorTests(unittest.TestCase):
    def test_mixed_objectives_and_reference_loot(self):
        pf = {
            "quests": {"data": {10: Table(obj=Table(I={1: 100, 2: 200})),
                                20: Table(obj=Table(I={1: 200}))}},
            "items": {"data": {100: Table(U={1: 50, 2: 100}, V={2: 0}, R={77: 1}),
                               200: Table(V={3: 0}, O={4: 100})}},
            "refloot": {"data": {77: Table(U={1: 0, 5: 0}, O={6: 0})}},
        }
        quests, items = project(pf)
        self.assertEqual(quests, {10: [100, 200]})
        self.assertEqual(items, {100: [1, 5]})

    def test_only_used_nonempty_source_lists_are_retained(self):
        quests, items = used_items({10: [100, 200]}, {100: [1], 200: [], 300: [3]})
        self.assertEqual(quests, {10: [100, 200]})
        self.assertEqual(items, {100: [1]})

    def test_deterministic_baseline_without_forever_overrides(self):
        first = render({20: [200], 10: [100]}, {200: [2], 100: [1]}, "pinned")
        second = render({10: [100], 20: [200]}, {100: [1], 200: [2]}, "pinned")
        self.assertEqual(first, second)
        self.assertIn("reviewed = {}", first)
        self.assertIn("Vanilla baseline only", first)

    def test_generation_rejects_source_pins_outside_the_review(self):
        manifest = {"revision": "pf-pinned", "upstream": {"revision": "vm-pinned"}}
        review = {"retain_existing_baseline": True, "pfquest": {"revision": "pf-pinned"},
                  "vmangos": {"revision": "vm-pinned"}}
        validate_review_pins(manifest, review)
        for changed in ({**manifest, "revision": "new-pf"},
                        {**manifest, "upstream": {"revision": "new-vm"}}):
            with self.assertRaisesRegex(ValueError, "licensing review"):
                validate_review_pins(changed, review)
        with self.assertRaisesRegex(ValueError, "retained"):
            validate_review_pins(manifest, {**review, "retain_existing_baseline": False})

    def test_notice_checksums_survive_windows_checkout(self):
        self.assertEqual(notice_hash(b"Notice\nTerms\n"), notice_hash(b"Notice\r\nTerms\r\n"))
        self.assertNotEqual(notice_hash(b"Notice\nTerms\n"), notice_hash(b"Changed\nTerms\n"))


if __name__ == "__main__":
    unittest.main()
