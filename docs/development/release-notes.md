# Release-note writing standard

[Build and release](build-and-release.md)

Release notes should tell a user what changed in a few seconds. Write the result they can see or use. Every version must pass this editorial review before its tag is created or pushed.

## Copy rules

- Aim for 1–3 bullets. The limit is 5 across all sections; a small fix can have just one.
- Describe one concrete change per bullet. Name the feature and the changed behavior. Put the most useful change first.
- Keep English bullets within 20 words and Chinese bullets within 60 characters, including punctuation. Titles have at most 6 English words or 20 Chinese characters. English words are counted by whitespace.
- Use plain verbs: “Add,” “Keep,” “Show,” or “Fixed.” Omit introductions, closing remarks, repeated benefits, and promotional adjectives.
- Keep both languages equally specific. A translation must retain the same limitations and meaning.
- Select meaningful user-facing changes. Omit internal refactors, tests, dependency chores, and implementation explanations unless they change something users need to know.
- Name only the fixes users would notice. Group the rest into one final bullet under Fixed, written exactly “Small bug fixes.” / “修复了一些小问题。” This is the only generic bullet allowed.

| Avoid | Write |
| --- | --- |
| We’re excited to introduce a seamless new tab experience. | Start a new session from a tab’s right-click menu. |
| Various performance and stability improvements. | Fixed freezes when reading image messages. |
| Improved session management. | Resume an ended session in its existing tab. |

The examples illustrate wording, not claims to reuse. Describe only changes that actually ship in that version.

## Required editorial review

Compare the previous release tag with the candidate commit. Read the relevant code, PRs, and verification evidence; commit titles alone are insufficient.

1. **Accurate:** Does each bullet describe behavior present in this release? Preserve restrictions such as local-only support or a specific CLI. Performance claims need measurements matching their scope.
2. **Useful:** Can a user tell what changed? Include breaking changes, compatibility changes, and required actions before optional highlights. Never remove a necessary qualification or action just to shorten the text.
3. **Brief:** Is each word needed? Remove filler, repetition, internal details, and vague “improvements.” Read the rendered English and Chinese notes aloud.
4. **Traceable:** Record the previous tag, candidate commit, and a supporting PR, commit, or test for each bullet in the release PR or delivery summary.

If essential changes cannot fit, revise this standard explicitly in the release PR with a reason before tagging. Do not silently bypass a check or omit essential information.

## Choosing the version

Choose the version before writing the notes, from what users get since the previous release. Sparkle offers an update by its build number (`CFBundleVersion`, the publish run's number plus 19), so the version only tells people what kind of release it is.

- **Major (2.0.0):** existing users must act or would lose something. For example, the minimum macOS version rises, a supported CLI or a relied-on feature goes, saved settings, bookmarks, or tabs change so an older version can't read them or must be migrated one way, or how sessions are found, resumed, or stored changes fundamentally.
- **Minor (1.3.0):** a new capability, not an improvement to one: a newly supported CLI, a new surface such as the conversation map or bookmarks, or a new workflow or major setting.
- **Patch (1.2.22):** fixes and refinements to what exists, including new options and shortcuts within an existing feature.

When patch and minor both seem to fit, ask whether the release title names something users couldn't do at all before. If it does, make it a minor release. The highest level any change reaches decides, and a minor or major release resets the numbers after it to 0. Record the level and the change that decided it in the release PR.

**1.4.0 exception:** Use a minor version for this release's [SSH cache migration](../requirements/remote/ssh-hosts.md) (SSH-106). It changes rebuildable local copies while preserving original session data and compatibility of saved settings, bookmarks, and tabs. Some legacy caches require reconnecting to repopulate history; the notes must state that conditional action first. The other changes are fixes that would warrant a patch; this cache migration is the reason for 1.4.0. This release-specific exception does not relax the major rule for durable data, supported features, or other required user actions.

Before this standard, every release after 1.2.0 was a patch. By it, 1.2.18 (bookmarks and the conversation map) and 1.2.20 (Kiro CLI V3 sessions) would have been minor releases. Published versions keep their numbers.

## Pre-tag check

Update `Sources/JustSessions/Resources/ReleaseNotes/releases.json`, keeping the candidate version first. Preview the copy while editing:

```sh
make release-notes-check RELEASE_TAG=vX.Y.Z
```

After committing and completing the editorial review, run:

```sh
make release-check RELEASE_TAG=vX.Y.Z
```

This checks the selected version, previews both languages, and runs `make verify`. It does not create or push a tag. Tag that exact commit only after the review and checks pass.

The shared catalog validator rejects excessive length, too many bullets, duplicate bullets, common filler, generic improvement claims other than the exact “Small bug fixes.” bullet last under Fixed, and missing translations. It runs during `make verify`, website builds, and release preparation, so the publication workflow repeats it before signing. The validator checks measurable writing rules; the required editorial review checks truth, relevance, and natural wording.
