"""Check translation coverage and interpolation contracts before packaging a catalog."""
import re

FORMAT_ARGUMENT = re.compile(r'%(?:(\d+)\$)?[-+ #0]*(?:\d+)?(?:\.\d+)?(hh|ll|[hljztL])?([@diuoxXfFeEgGaAcCsSp])')
SUBSTITUTION = re.compile(r'%(?:(\d+)\$)?#@([^@]+)@')
COUNT_ARGUMENT_TYPES = {'d', 'ld', 'lld', 'u', 'lu', 'llu'}


def format_arguments(value):
    arguments = {}
    next_position = 1
    for match in FORMAT_ARGUMENT.finditer(value.replace('%%', '')):
        position = int(match[1]) if match[1] else next_position
        next_position += match[1] is None
        argument_type = (match[2] or '') + match[3]
        if position in arguments and arguments[position] != argument_type:
            raise ValueError(f'Argument {position} has conflicting format types')
        arguments[position] = argument_type
    return arguments


def string_units(node, substitutions=None, plural_form=None, argument_number=None):
    substitutions = dict(substitutions or {})
    substitutions.update(node.get('substitutions', {}))
    if 'stringUnit' in node:
        value = node['stringUnit']['value']
        def replace_substitution(match):
            name = match[2]
            if name not in substitutions:
                raise ValueError(f'Undefined substitution {name!r}')
            substitution = substitutions[name]
            argument_number = substitution.get('argNum')
            format_specifier = substitution.get('formatSpecifier', '')
            if not isinstance(argument_number, int) or argument_number < 1 or not FORMAT_ARGUMENT.fullmatch('%' + format_specifier):
                raise ValueError(f'Invalid substitution {name!r}')
            if match[1] and int(match[1]) != argument_number:
                raise ValueError(f'Conflicting position for substitution {name!r}')
            return f'%{argument_number}${format_specifier}'
        value = SUBSTITUTION.sub(replace_substitution, value)
        yield node['stringUnit'], value, plural_form, argument_number
    for name, child in node.items():
        if name == 'stringUnit' or not isinstance(child, dict):
            continue
        if name == 'substitutions':
            for substitution in child.values():
                yield from string_units(substitution, substitutions, plural_form, substitution.get('argNum'))
        elif name == 'plural':
            for form, variation in child.items():
                yield from string_units(variation, substitutions, form, argument_number)
        else:
            yield from string_units(child, substitutions, plural_form, argument_number)


def source_arguments(key, entry, source_language):
    # Stable catalog keys need not contain the English text. Take their interpolation contract from the
    # source localization, including every source plural form, but exclude each substitution's local scope.
    source_units = [value for _, value, _, argument_number in string_units(entry.get('localizations', {}).get(source_language, {}))
                    if argument_number is None]
    arguments = {}
    for value in source_units or [key]:
        for position, argument_type in format_arguments(value).items():
            if position in arguments and arguments[position] != argument_type:
                raise ValueError(f'Argument {position} has conflicting source types')
            arguments[position] = argument_type
    return arguments


def validate_catalog(catalog):
    source_language = catalog['sourceLanguage']
    languages = sorted({language for entry in catalog['strings'].values() for language in entry.get('localizations', {})} - {source_language})
    errors = []
    for key, entry in catalog['strings'].items():
        if entry.get('extractionState') == 'stale':
            errors.append(f'{key!r}: stale source string; remove it from the catalog')
        if entry.get('shouldTranslate') is False:
            continue
        try:
            expected_arguments = source_arguments(key, entry, source_language)
        except ValueError as error:
            errors.append(f'{key!r}: {error}')
            continue
        for language in languages:
            localization = entry.get('localizations', {}).get(language)
            try:
                units = list(string_units(localization)) if localization else []
            except ValueError as error:
                errors.append(f'{language}: {key!r}: {error}')
                continue
            if not units:
                errors.append(f'{language}: missing translation for {key!r}')
                continue
            for unit, value, plural_form, argument_number in units:
                if unit.get('state') != 'translated' or (key and not value):
                    errors.append(f'{language}: unfinished translation for {key!r}')
                try:
                    actual_arguments = format_arguments(value)
                except ValueError as error:
                    errors.append(f'{language}: {key!r}: {error}')
                    continue
                # A substitution formats only its own argument; it does not repeat the outer sentence's
                # project name or other values. Its plural strings receive that argument in position one.
                if argument_number is not None and argument_number not in expected_arguments:
                    errors.append(f'{language}: unknown substitution argument {argument_number} in {key!r}')
                    continue
                unit_arguments = {1: expected_arguments[argument_number]} if argument_number is not None else expected_arguments
                # Zero/one/two can express their count in words, but never drop another argument or the
                # changing count in "other". A standalone plural varies its first numeric argument.
                required = dict(unit_arguments)
                if plural_form in {'zero', 'one', 'two'}:
                    plural_argument = next((position for position, kind in unit_arguments.items() if kind in COUNT_ARGUMENT_TYPES), None)
                    required.pop(plural_argument, None)
                if any(unit_arguments.get(position) != kind for position, kind in actual_arguments.items()) or any(actual_arguments.get(position) != kind for position, kind in required.items()):
                    errors.append(f'{language}: incompatible interpolation in {key!r}: {value!r}')
    return errors
