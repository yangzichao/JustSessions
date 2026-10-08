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

The shared catalog validator rejects excessive length, too many bullets, duplicate bullets, common filler, generic improvement claims, and missing translations. It runs during `make verify`, website builds, and release preparation, so the publication workflow repeats it before signing. The validator checks measurable writing rules; the required editorial review checks truth, relevance, and natural wording.
