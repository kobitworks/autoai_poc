from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Main.gd").read_text(encoding="utf-8")
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")


class MobileUiContractTests(unittest.TestCase):
    def test_mobile_reference_viewport_is_phone_first(self):
        width = int(re.search(r"window/size/viewport_width=(\d+)", PROJECT).group(1))
        height = int(re.search(r"window/size/viewport_height=(\d+)", PROJECT).group(1))
        self.assertLessEqual(width, 420)
        self.assertGreaterEqual(height, 800)

    def test_portrait_layout_can_scroll_instead_of_shrinking_text(self):
        self.assertIn("ScrollContainer.new()", MAIN)
        self.assertIn("vertical_scroll_mode", MAIN)

    def test_crop_selection_uses_large_buttons_not_a_dropdown(self):
        self.assertNotIn("OptionButton.new()", MAIN)
        self.assertIn("crop_buttons", MAIN)
        self.assertIn("_choose_crop", MAIN)

    def test_status_is_split_into_readable_cards(self):
        self.assertIn("stats_grid = GridContainer.new()", MAIN)
        self.assertIn("stats_labels", MAIN)

    def test_mobile_typography_and_touch_targets_have_minimum_sizes(self):
        self.assertIn("ui_theme.default_font_size = 18", MAIN)
        self.assertRegex(MAIN, r"custom_minimum_size\s*=\s*Vector2\(0,\s*58\)")
        self.assertIn('help.add_theme_font_size_override("font_size", 15)', MAIN)
        self.assertIn('log_view.add_theme_font_size_override("font_size", 15)', MAIN)


if __name__ == "__main__":
    unittest.main()
