"""python3 -m unittest discover tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from hawwel.converter import convert, is_to_arabic  # noqa: E402


class ConverterTests(unittest.TestCase):
    def test_english_to_arabic(self):
        self.assertEqual(convert("lvpfh"), "مرحبا")
        self.assertEqual(convert("hgsghl ugd;l"), "السلام عليكم")
        self.assertEqual(convert("bl"), "لام")

    def test_arabic_to_english(self):
        self.assertEqual(convert("مرحبا"), "lvpfh")
        self.assertEqual(convert("اثممخ صخقمي"), "hello world")
        self.assertEqual(convert("أحمد"), "Hpl]")

    def test_caps_lock(self):
        self.assertEqual(convert("LVPFH"), "مرحبا")

    def test_direction(self):
        self.assertTrue(is_to_arabic("hello"))
        self.assertFalse(is_to_arabic("مرحبا"))


if __name__ == "__main__":
    unittest.main()
