"""Read the app's explicit provider switches; fail if their representation changes."""

import re
from pathlib import Path


def read_switch_values(source, switch_pattern, value_pattern, provider_identifiers):
    switch_match = re.search(switch_pattern, source, re.DOTALL)
    assert switch_match, "Cannot read the app capability switch; update the website source reader"
    values = {}
    for case_match in re.finditer(rf"case\s+([.\w,\s]+):\s*({value_pattern})", switch_match[1]):
        for identifier in re.findall(r"\.(\w+)", case_match[1]):
            assert identifier not in values, f"Repeated provider case: {identifier}"
            values[identifier] = case_match[2]
    assert set(values) == set(provider_identifiers), "Unrecognized capability cases; update the website source reader"
    return values


def read_app_capabilities(repository_directory: Path):
    provider_source = (repository_directory / "Sources/JustSessions/Models/Conversations/ConversationProvider.swift").read_text()
    provider_names = dict(re.findall(r'^\s{4}case (\w+) = "([^"]+)"', provider_source, re.MULTILINE))
    assert provider_names, "Cannot find app providers"
    capabilities = {identifier: {"name": name} for identifier, name in provider_names.items()}

    for capability, property_name, value_pattern in (
        ("command", "executableName", r'"[^"]+"'),
        ("branch", "supportsBranchFromLauncher", "true|false"),
        ("ssh", "supportsRemoteHosts", "true|false"),
        ("delete", "supportsDeletionFromLauncher", "true|false"),
    ):
        switch_pattern = rf"\bvar {property_name}: [^{{]+{{\s*switch self\s*{{([^}}]+)}}"
        values = read_switch_values(provider_source, switch_pattern, value_pattern, provider_names)
        for identifier, value in values.items():
            capabilities[identifier][capability] = value.strip('"') if capability == "command" else value == "true"

    transcript_source = (repository_directory / "Sources/JustSessions/Services/Transcript/TranscriptLoader.swift").read_text()
    preview_values = read_switch_values(
        transcript_source, r"switch conversation\.provider\s*{([^}]+)}", r"\.(?:loaded|unsupported)\b", provider_names,
    )
    for identifier, value in preview_values.items():
        capabilities[identifier]["preview"] = value == ".loaded"
    return capabilities
