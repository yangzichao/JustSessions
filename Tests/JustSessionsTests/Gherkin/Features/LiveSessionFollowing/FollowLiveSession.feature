Feature: An Antigravity, Pi, or OpenCode tab follows the session its CLI is in

  Antigravity logs the conversation its CLI opens. Pi and OpenCode report the session they show through a small
  extension the app starts them with on this Mac. The app reads these every second, so a new session's tab finds
  its session, and a tab follows its CLI when /new, /clear, /resume, or /fork moves it to another session. A
  session the app has not listed yet is listed with one refresh once the tool saves it.

  Scenario Outline: After the CLI moves to another session the tab follows it
    Given a tab whose <tool> CLI resumed the session "Before"
    And the sidebar lists the session "After"
    When the CLI in the tab moves to "After"
    Then the tab shows the session "After"
    And the tab is titled "After"
    And the sidebar still lists "Before"

    Examples:
      | tool        |
      | Antigravity |
      | Pi          |
      | OpenCode    |

  Scenario Outline: A session the CLI moved to is listed once the tool saves it
    Given a tab whose <tool> CLI resumed the session "Before"
    When the CLI in the tab moves to "After", which it has not saved yet
    Then the tab shows the session "Before"
    When the CLI saves "After"
    Then the sidebar lists "After"
    And the tab shows the session "After"

    Examples:
      | tool        |
      | Antigravity |
      | Pi          |
      | OpenCode    |

  Scenario Outline: A new session's tab finds its session
    Given a tab whose <tool> CLI started a new session
    When the CLI in the tab moves to "First prompt", which it has not saved yet
    And the CLI saves "First prompt"
    Then the sidebar lists "First prompt"
    And the tab shows the session "First prompt"
    And the tab is titled "First prompt"

    Examples:
      | tool        |
      | Antigravity |
      | Pi          |
      | OpenCode    |

  Scenario: OpenCode's home screen leaves the tab with its session
    Given a tab whose OpenCode CLI resumed the session "Before new"
    When the OpenCode CLI in the tab shows its home screen
    Then the tab shows the session "Before new"
    And the tab is titled "Before new"
