import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from catalog_validation import validate_catalog


def catalog(key, translation, language='zh-Hans'):
    return {'sourceLanguage': 'en', 'strings': {key: {'localizations': {
        language: {'stringUnit': {'state': 'translated', 'value': translation}}
    }}}}


class CatalogValidationTests(unittest.TestCase):
    def test_accepts_reordered_arguments(self):
        self.assertEqual(validate_catalog(catalog('%@: %lld sessions', '%2$lld 个会话：%1$@')), [])

    def test_rejects_changed_argument_type(self):
        self.assertTrue(validate_catalog(catalog('%lld sessions', '%@ 个会话')))

    def test_rejects_dropped_argument(self):
        self.assertTrue(validate_catalog(catalog('Session on %@', '会话')))

    def test_requires_all_languages_to_cover_all_keys(self):
        example = catalog('General', '通用')
        example['strings']['Settings'] = catalog('Settings', '設定', 'ja')['strings']['Settings']
        self.assertEqual(len(validate_catalog(example)), 2)

    def test_accepts_plural_forms_and_positional_substitutions(self):
        example = catalog('%lld sessions', '')
        example['strings']['%lld sessions']['localizations']['zh-Hans'] = {
            'variations': {'plural': {
                'one': {'stringUnit': {'state': 'translated', 'value': '一个会话'}},
                'other': {'stringUnit': {'state': 'translated', 'value': '%lld 个会话'}}
            }}
        }
        self.assertEqual(validate_catalog(example), [])

    def test_ignores_percent_literals(self):
        self.assertEqual(validate_catalog(catalog('Progress: %lld%%', '进度：%lld%%')), [])

    def test_plural_substitutions_preserve_outer_argument_positions(self):
        example = catalog('%@: %lld sessions', '')
        example['strings']['%@: %lld sessions']['localizations']['zh-Hans'] = {
            'stringUnit': {'state': 'translated', 'value': '%1$@：%#@count@'},
            'substitutions': {'count': {'argNum': 2, 'formatSpecifier': 'lld', 'variations': {'plural': {
                'one': {'stringUnit': {'state': 'translated', 'value': '一个会话'}},
                'other': {'stringUnit': {'state': 'translated', 'value': '%lld 个会话'}}
            }}}}
        }
        self.assertEqual(validate_catalog(example), [])

    def test_ignores_brand_names(self):
        example = catalog('JustSessions', '')
        example['strings']['JustSessions']['shouldTranslate'] = False
        self.assertEqual(validate_catalog(example), [])

    def test_stable_keys_use_source_localization_for_interpolation(self):
        example = catalog('sessions.count', '%2$lld 个会话：%1$@')
        entry = example['strings']['sessions.count']
        entry['localizations']['en'] = {'stringUnit': {'state': 'translated', 'value': '%@: %lld sessions'}}
        self.assertEqual(validate_catalog(example), [])
        entry['localizations']['zh-Hans']['stringUnit']['value'] = '%@ 个会话'
        self.assertTrue(validate_catalog(example))

    def test_reports_undefined_substitutions_instead_of_crashing(self):
        errors = validate_catalog(catalog('%lld sessions', '%#@missing@'))
        self.assertTrue(any('Undefined substitution' in error for error in errors))

    def test_rejects_substitution_for_an_unknown_argument(self):
        example = catalog('%lld sessions', '%#@count@')
        example['strings']['%lld sessions']['localizations']['zh-Hans']['substitutions'] = {
            'count': {'argNum': 2, 'formatSpecifier': 'lld', 'variations': {'plural': {
                'other': {'stringUnit': {'state': 'translated', 'value': '%lld 个会话'}}
            }}}
        }
        self.assertTrue(validate_catalog(example))

    def test_accepts_explicit_positions_on_plural_substitutions(self):
        example = catalog('%@: %lld sessions', '%1$@：%2$#@count@')
        example['strings']['%@: %lld sessions']['localizations']['zh-Hans']['substitutions'] = {
            'count': {'argNum': 2, 'formatSpecifier': 'lld', 'variations': {'plural': {
                'other': {'stringUnit': {'state': 'translated', 'value': '%lld 个会话'}}
            }}}
        }
        self.assertEqual(validate_catalog(example), [])

    def test_plural_other_must_preserve_its_changing_count(self):
        example = catalog('%lld sessions', '')
        example['strings']['%lld sessions']['localizations']['zh-Hans'] = {
            'variations': {'plural': {'other': {'stringUnit': {'state': 'translated', 'value': '会话'}}}}
        }
        self.assertTrue(validate_catalog(example))

    def test_worded_plural_preserves_other_numeric_arguments(self):
        example = catalog('%lld sessions in %lld projects', '')
        localization = {'variations': {'plural': {
            'one': {'stringUnit': {'state': 'translated', 'value': '一个会话，%2$lld 个项目'}},
            'other': {'stringUnit': {'state': 'translated', 'value': '%lld 个会话，%lld 个项目'}}
        }}}
        example['strings']['%lld sessions in %lld projects']['localizations']['zh-Hans'] = localization
        self.assertEqual(validate_catalog(example), [])
        localization['variations']['plural']['one']['stringUnit']['value'] = '一个会话'
        self.assertTrue(validate_catalog(example))


if __name__ == '__main__':
    unittest.main()
