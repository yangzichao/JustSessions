Feature: A name chosen with /rename shows while Claude Code runs in a tab

  Claude Code keeps a live registry of each running CLI: the session it is in, and the name chosen for it
  with /rename. The app reads it every second, so the name shows on the tab and on the session's row in the
  sidebar without a refresh. /clear moves the CLI to a new session and keeps the name, so the tab follows
  the CLI there.

  Scenario: Renaming a resumed session renames its tab and its row
    Given a tab resumed the Claude Code session "First prompt"
    When the CLI in the tab is renamed to "Renamed live"
    Then the tab is titled "Renamed live"
    And the sidebar lists "Renamed live"
    But the sidebar no longer lists "First prompt"

  Scenario: A name the CLI made up itself leaves the titles alone
    Given a tab resumed the Claude Code session "First prompt"
    When the CLI in the tab names itself "justsessions-03"
    Then the tab is titled "First prompt"
    And the sidebar lists "First prompt"

  Scenario: Renaming a new session before it is listed renames its tab
    Given a tab started a new Claude Code session
    When the CLI in the tab is renamed to "Brand new name"
    Then the tab is titled "Brand new name"

  Scenario: Renaming a new session that is listed renames its row too
    Given a tab started a new Claude Code session
    And the sidebar lists the new session as "Stale first prompt"
    When the CLI in the tab is renamed to "Brand new name"
    Then the tab is titled "Brand new name"
    And the sidebar lists "Brand new name"
    But the sidebar no longer lists "Stale first prompt"

  Scenario: After /clear the tab follows the CLI to its new session
    Given a tab resumed the Claude Code session "Before clear"
    And the sidebar lists the Claude Code session "After clear"
    When the CLI in the tab moves to "After clear" with /clear
    Then the tab shows the session "After clear"
    And the tab is titled "After clear"
    And the sidebar still lists "Before clear"

  Scenario: Renaming after /clear renames the session the CLI moved to
    Given a tab resumed the Claude Code session "Before clear"
    And the sidebar lists the Claude Code session "After clear"
    When the CLI in the tab moves to "After clear" with /clear
    And the CLI in the tab is renamed to "menu-actions-implementation"
    Then the tab is titled "menu-actions-implementation"
    And the sidebar lists "menu-actions-implementation"
    And the sidebar still lists "Before clear"
    But the sidebar no longer lists "After clear"

  Scenario: The session /clear started is found with a refresh
    Given a tab resumed the Claude Code session "Before clear"
    And Claude Code wrote the session "After clear", which the sidebar does not list yet
    When the CLI in the tab moves to "After clear" with /clear
    Then the sidebar lists "After clear"
    And the tab shows the session "After clear"
