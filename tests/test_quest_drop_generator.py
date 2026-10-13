"""Projection safeguards that prevent incorrect hostile loot relationships."""
import unittest

from tools.build_quest_drops import apply_overrides, project, render


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

    def test_reviewed_requirements_replace_old_sources(self):
        quests, items = apply_overrides({10: [100, 200]}, {100: [1], 200: [2]},
            {"quests": {"10": [200, 300]}, "items": {"200": [], "300": [3]}})
        self.assertEqual(quests, {10: [200, 300]})
        self.assertEqual(items, {300: [3]})

    def test_deterministic_data_and_reviewed_flags(self):
        first = render({20: [200], 10: [100]}, {200: [2], 100: [1]}, "pinned", [20, 10])
        second = render({10: [100], 20: [200]}, {100: [1], 200: [2]}, "pinned", [10, 20])
        self.assertEqual(first, second)
        self.assertIn("reviewed = {[10] = true, [20] = true}", first)


if __name__ == "__main__":
    unittest.main()
