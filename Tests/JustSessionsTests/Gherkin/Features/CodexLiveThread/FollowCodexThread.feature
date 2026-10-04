Feature: A Codex tab follows the thread its CLI is in

  Codex names the thread its CLI is in only in the terminal title, as the start of the thread's id, and the
  app starts Codex that way on this Mac. The app reads the title every second, so a new session's tab finds
  its thread, and a tab follows its CLI when /new, /clear, /resume, or /fork moves it to another thread.
  A thread that /new starts gets its rollout file with the first prompt; a refresh lists it once it is saved.

  Scenario: After /new the tab follows the CLI to its new thread
    Given a tab resumed the Codex session "Before new"
    And the sidebar lists the Codex session "After new"
    When the Codex CLI in the tab moves to "After new" with /new
    Then the tab shows the session "After new"
    And the tab is titled "After new"
    And the sidebar still lists "Before new"

  Scenario: The thread /new started is found with a refresh
    Given a tab resumed the Codex session "Before new"
    And Codex saved the session "After new", which the sidebar does not list yet
    When the Codex CLI in the tab moves to "After new" with /new
    Then the sidebar lists "After new"
    And the tab shows the session "After new"

  Scenario: A thread is listed once its first prompt saves it
    Given a tab resumed the Codex session "Before new"
    When the Codex CLI in the tab moves with /new to "After new", which Codex has not saved yet
    Then the tab shows the session "Before new"
    When Codex saves "After new" with its first prompt
    Then the sidebar lists "After new"
    And the tab shows the session "After new"

  Scenario: A new session's tab finds its thread
    Given a tab started a new Codex session
    When the Codex CLI in the tab starts "First prompt", which Codex has not saved yet
    And Codex saves "First prompt" with its first prompt
    Then the sidebar lists "First prompt"
    And the tab shows the session "First prompt"
    And the tab is titled "First prompt"

  Scenario: A title that names no thread leaves the tab alone
    Given a tab resumed the Codex session "Before new"
    And the sidebar lists the Codex session "After new"
    When the Codex CLI in the tab sets the title "After new"
    Then the tab shows the session "Before new"
    And the tab is titled "Before new"
