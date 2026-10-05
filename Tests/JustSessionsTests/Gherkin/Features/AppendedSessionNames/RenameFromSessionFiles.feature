Feature: A name a CLI appends to a file shows while its tab is open

  Claude Code's /rename and Pi's /name add a line naming the session to the session's own file, and Codex adds one
  to its session_index.jsonl whenever it names or renames a thread. The app reads what these files gain every
  second, so the new name shows on the tab and on the session's row in the sidebar without a refresh. For Claude
  Code this backs up its live registry, which some setups leave without the name.

  Scenario Outline: A name the CLI appends renames the tab and its row
    Given a <tool> tab is open on the session "First prompt"
    When the CLI appends the name "Renamed in its file"
    Then the tab is titled "Renamed in its file"
    And the sidebar lists "Renamed in its file"
    But the sidebar no longer lists "First prompt"

    Examples:
      | tool   |
      | Claude |
      | Pi     |
      | Codex  |

  Scenario: A name Codex gives another thread leaves the tab alone
    Given a Codex tab is open on the session "First prompt"
    When Codex appends the name "Another thread" for another thread
    Then the tab is titled "First prompt"
    And the sidebar lists "First prompt"

  Scenario Outline: A name given in the app stays ahead of one the CLI appends
    Given a <tool> tab is open on the session "First prompt"
    And the session is renamed "Named in the app" in the app
    When the CLI appends the name "Renamed in its file"
    Then the tab is titled "Named in the app"

    Examples:
      | tool   |
      | Claude |
      | Codex  |
