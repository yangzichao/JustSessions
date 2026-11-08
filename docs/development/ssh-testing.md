# SSH development testing

[Contributing](../../CONTRIBUTING.md) · [Build and release](build-and-release.md) · [SSH user guide](../guides/session-management.md#ssh-hosts)

Contributors develop and run JustSessions on macOS. Our standard Linux SSH test target is a disposable Ubuntu 24.04 VM running locally in Multipass. It needs no cloud account or second computer, gives each contributor an independent test environment, and exercises Linux tools and paths through real SSH. The app and its build tools stay on the Mac.

Use a separate macOS account or another Mac as well when changing remote shell commands, paths, or platform-dependent tools. A Linux result does not verify macOS behavior, and a local VM does not establish behavior across an unreliable internet connection. SSH to your everyday Mac account exposes the same session files the app reads locally; use disposable accounts and sessions for deletion tests.

## Create the Linux target

Install [Multipass](https://canonical.com/multipass/docs/latest/how-to-guides/install-multipass/) with its macOS installer, or with Homebrew:

```sh
brew install --cask multipass
```

Installation needs administrator access. Create the named VM from a Mac terminal. We pin Ubuntu 24.04 so contributors use the same release rather than a changing `lts` alias. Increase the resources if the CLI workload needs them.

```sh
multipass launch 24.04 --name justsessions-ssh-test --cpus 2 --memory 2G --disk 10G
multipass exec justsessions-ssh-test -- sudo apt-get update
multipass exec justsessions-ssh-test -- sudo apt-get install -y rsync tmux python3 lsof curl git
```

Use `multipass list` first if the VM may already exist; start an existing one with `multipass start justsessions-ssh-test`. Keep projects inside the VM rather than mounting your Mac's working folders into it.

If `multipass exec`, `transfer`, or `shell` fails with `No route to host` while `multipass list` shows the VM running, run the Multipass commands from Terminal.app. On macOS 26.5, they failed inside a tmux session and worked from Terminal.app; `ping` and `ssh` to the VM worked from both.

## Configure key-based SSH

Each contributor uses their own key. In a Mac terminal, create a dedicated test key if it does not already exist; choose a passphrase when prompted and load it into the macOS keychain and SSH agent:

```sh
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/justsessions-test" ]; then
  ssh-keygen -t ed25519 -f "$HOME/.ssh/justsessions-test" -C "JustSessions test host"
fi
ssh-add --apple-use-keychain "$HOME/.ssh/justsessions-test"
multipass transfer "$HOME/.ssh/justsessions-test.pub" justsessions-ssh-test:/home/ubuntu/justsessions-test-key.pub
multipass exec justsessions-ssh-test -- sh -c 'cat "$HOME/justsessions-test-key.pub" >> "$HOME/.ssh/authorized_keys" && chmod 600 "$HOME/.ssh/authorized_keys" && rm "$HOME/justsessions-test-key.pub"'
multipass info justsessions-ssh-test
```

Only the public key is copied to the VM. Add the following block near the start of `~/.ssh/config`, before broad `Host *` defaults, replacing `VM_IP_ADDRESS` with the VM's IPv4 address. If the alias already exists, update its block instead of adding a second one.

```sshconfig
Host justsessions-test
    HostName VM_IP_ADDRESS
    User ubuntu
    IdentityFile ~/.ssh/justsessions-test
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
    HostKeyAlias justsessions-test
```

Check the VM's host-key fingerprint through Multipass, then make the first SSH connection interactively. Accept the host key only when its fingerprint matches. The final command must succeed without asking for a password or passphrase; the checks below use this alias. [Hosts that ask to log in](#hosts-that-ask-to-log-in) covers **Connect…**.

```sh
multipass exec justsessions-ssh-test -- ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh -o HostKeyAlgorithms=ssh-ed25519 justsessions-test true
ssh -o BatchMode=yes justsessions-test 'command -v rsync && command -v python3 && command -v lsof && tmux -V'
```

If the batch check fails, resolve SSH authentication before adding the host to the app. Check `multipass info justsessions-ssh-test` again after restarting the VM; its IP can change. If you deliberately recreate the VM, verify its new fingerprint, remove only its old entry with `ssh-keygen -R justsessions-test`, then repeat the interactive connection and batch check.

## Prepare a provider and project

Open `multipass shell justsessions-ssh-test` and install the CLI being tested using that provider's current Linux instructions. Sign in inside the VM through its supported login flow. Test each affected provider separately; one working CLI does not establish coverage for the others.

Create a disposable project, including a space in its path to exercise quoting:

```sh
ssh justsessions-test 'mkdir -p "$HOME/justsessions-test/project with spaces"'
```

The app runs CLIs and looks them up through the host's interactive login shell, `exec "$SHELL" -lic`, so the PATH set in `~/.bashrc`, such as nvm's, is in effect. A non-interactive `bash -lc` skips Ubuntu's `~/.bashrc` and can miss a CLI the app finds. For example, when testing Claude Code, check it the same way the app does:

```sh
ssh -o BatchMode=yes justsessions-test 'exec "$SHELL" -lic "type claude && claude --version"'
```

Without a terminal, bash first prints `cannot set terminal process group` and `no job control in this shell`; those two lines are expected. Substitute the executable for the provider being tested. Keep its session storage at the locations documented in [session storage](../guides/session-storage.md#ssh-session-cache). `rsync` is required for history mirroring; Antigravity and OpenCode also require `python3`, and Antigravity deletion requires `lsof`. Remote persistence uses the VM's `tmux`, not the app's bundled Mac binary.

The VM has a local network address, so on macOS 15 and later JustSessions needs Local Network access to reach it, as for any SSH host on your network; see **Settings → Permissions**. In JustSessions, choose **Add SSH host…**, enter `justsessions-test`, then add `/home/ubuntu/justsessions-test/project with spaces` under that host. Start a small disposable conversation so the host has real session history to discover and preview.

## Hosts that ask to log in

**Connect…** logs in to a host that asks for a password, a passphrase, or a code. Test it with separate users on the same VM, so the `justsessions-test` alias keeps working without a prompt. Use throwaway values; the ones below are examples.

A password user:

```sh
ssh justsessions-test 'set -e
id pwtest >/dev/null 2>&1 || sudo useradd -m -s /bin/bash pwtest
echo "pwtest:js-test-pass" | sudo chpasswd
printf "Match User pwtest\n    PasswordAuthentication yes\n    KbdInteractiveAuthentication yes\n" | sudo tee /etc/ssh/sshd_config.d/70-justsessions-password-test.conf >/dev/null
sudo sshd -t && sudo systemctl reload ssh'
```

Add it as `pwtest@VM_IP_ADDRESS`. Ubuntu asks for its password by keyboard-interactive, as `(pwtest@VM_IP_ADDRESS) Password:`. Its host key is not yet known under that name, so the first **Connect…** also asks to trust it; compare the fingerprint with the one from `multipass exec`.

A user that asks for a password and then a verification code:

```sh
ssh justsessions-test 'set -e
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libpam-google-authenticator
id totptest >/dev/null 2>&1 || sudo useradd -m -s /bin/bash totptest
echo "totptest:js-test-pass" | sudo chpasswd
sudo -u totptest -H google-authenticator -t -d -f -C -u -w 3 -e 0 -Q NONE -q
grep -q pam_google_authenticator /etc/pam.d/sshd || sudo sed -i "/^@include common-auth/a auth required pam_google_authenticator.so nullok" /etc/pam.d/sshd
printf "Match User totptest\n    KbdInteractiveAuthentication yes\n    PasswordAuthentication no\n    AuthenticationMethods keyboard-interactive\n" | sudo tee /etc/ssh/sshd_config.d/71-justsessions-totp-test.conf >/dev/null
sudo sshd -t && sudo systemctl reload ssh'
```

The first line of `/home/totptest/.google_authenticator` is the base32 secret. Read it with `sudo head -1`, and add it to an authenticator app, or print the current code from a file holding it:

```sh
python3 -c 'import base64,hmac,struct,sys,time; s=open(sys.argv[1]).read().strip().upper(); k=base64.b32decode(s+"="*(-len(s)%8)); d=hmac.new(k,struct.pack(">Q",int(time.time())//30),"sha1").digest(); o=d[-1]&15; print("%06d"%((struct.unpack(">I",d[o:o+4])[0]&0x7FFFFFFF)%1000000))' SECRET_FILE
```

`-d` refuses a code that was used already, so wait for the next one between logins. `nullok` lets users without a secret, such as `ubuntu` and `pwtest`, log in as before.

A key with a passphrase that the agent does not hold: create a key with a passphrase, authorize it for `pwtest`, and give it an alias with `IdentityFile` set to it, `IdentitiesOnly yes`, `IdentityAgent none`, `PreferredAuthentications publickey`, and `HostKeyAlias justsessions-test`. An empty answer makes `ssh` skip the key, so the login is refused.

Remove these users, their `sshd_config.d` files, the `pam_google_authenticator` line, the alias, and any known-host entry the test trusted when you no longer need them.

## Hosts whose login shell is fish

`sshd` hands every command the app sends to the user's login shell, and that shell also runs each CLI. fish reads quotes and some syntax differently from `sh`, bash, and zsh, so check remote commands with a VM user whose shell is fish:

```sh
ssh justsessions-test 'set -e
sudo apt-get install -y fish
sudo useradd -m -s /usr/bin/fish fishtest
sudo install -d -m 700 -o fishtest -g fishtest /home/fishtest/.ssh
sudo install -m 600 -o fishtest -g fishtest /home/ubuntu/.ssh/authorized_keys /home/fishtest/.ssh/authorized_keys'
```

`ssh fishtest@justsessions-test 'echo $FISH_VERSION'` prints fish's version (3.7.0 on Ubuntu 24.04). Add `fishtest@justsessions-test`, then check that its heading shows no shell startup warning, that a session starts and resumes in tmux, and that **Use this host's tmux prefix** reaches a running session.

## Windows hosts

The app tells a Windows host apart when it is added or refreshed, and says it isn't supported. To exercise that without a Windows machine, give a VM user PowerShell as its shell, with Windows' `OS` variable set. This stands in for a Windows host whose OpenSSH default shell is PowerShell; it does not cover `cmd.exe`, Windows' default, or a real Windows host.

```sh
ssh justsessions-test 'set -e
sudo mkdir -p /opt/pwsh-test
curl -fsSL https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-linux-arm64.tar.gz | sudo tar xz -C /opt/pwsh-test
sudo chmod -R a+rX /opt/pwsh-test && sudo chmod 755 /opt/pwsh-test/pwsh
printf "#!/bin/sh\nOS=Windows_NT exec /opt/pwsh-test/pwsh -NoProfile -NoLogo \"\$@\"\n" | sudo tee /usr/local/bin/winsim-pwsh >/dev/null
sudo chmod 755 /usr/local/bin/winsim-pwsh
echo /usr/local/bin/winsim-pwsh | sudo tee -a /etc/shells >/dev/null
sudo useradd -m -s /usr/local/bin/winsim-pwsh winsim
sudo install -d -m 700 -o winsim -g winsim /home/winsim/.ssh
sudo install -m 600 -o winsim -g winsim /home/ubuntu/.ssh/authorized_keys /home/winsim/.ssh/authorized_keys'
```

Use the `x64` archive on an Intel Mac's VM. Give the user an alias like `justsessions-test` with `User winsim`, then check that `ssh justsessions-test-windows 'echo %OS% $env:OS'` prints `%OS%` and `Windows_NT`. Adding the alias says it runs Windows; **Add anyway** lists it with the same note on its heading.

## Manual checks for an SSH change

Run the checks relevant to the change and record the result of each:

| Check | What to verify |
| --- | --- |
| Adding a host | Add the VM: the sheet shows **Connecting to…**, then adds it. Add a host that fails, such as a typo or the stopped VM: the sheet says why and offers **Try again** and **Add anyway**. |
| `~/.ssh/config` written for logging in by hand | Give the VM an alias with `RemoteCommand`, `RequestTTY force`, and a `LocalForward`. Refresh lists its sessions, and a tab opens the CLI, not the `RemoteCommand`. |
| Logging in with **Connect…** | Add a host that asks: the sheet says so and offers **Connect…**. Answer each question; a wrong answer says it wasn't accepted and asks again, and Cancel stops. The host is added and refreshes without asking again. **Connect…** on the heading does the same for a listed host. |
| Tabs and probes on a logged-in host | New sessions, resumed sessions, a plain terminal, and **Add project** connect without a prompt, in both terminal engines. **Disconnect** in ⋯ closes those tabs and ends the login, `ssh: …/master [mux]` gone from `ps`; **Reconnect** in a tab goes through the login open then, or asks in the terminal. Quitting the app and removing the host each end the login, `ssh: …/master [mux]` in `ps`. The login stays open with nothing using it; after `kill -9` of the app, the next launch ends the login it left. |
| Port forwarding | Start `python3 -m http.server 8000 --bind 127.0.0.1` on the VM. **Forward a port…** in the host's ⋯ and right-click menus lists 8000 with `python3`; forwarding it lists `localhost:8000 → 8000`, and **Open in browser** shows the server's folder. A port on this Mac that another program holds keeps the sheet open with ssh's `Address already in use`. With a tab open through an alias with a `LocalForward`, a forward still works. `ps` shows one `ssh -N … ClearAllForwardings=yes … forward-<pid>-…/master` for the host, which ends with its last **Stop forwarding**. After killing that `ssh`, the forward reads **Reconnecting…** and works again within seconds. A host logged in with **Connect…** starts no `ssh -N`, and **Disconnect** ends the host's forwards. Removing the host and quitting the app end the forwards; after `kill -9` of the app, the next launch ends the `ssh -N` it left. |
| Disconnect | With a session running in a tab on the VM, and a second window open, **Disconnect** in the heading's ⋯ asks **Keep running** or **End sessions**, closes the tab in both windows, and the heading reads **Disconnected** with its sessions still listed and none marked running. For 10 minutes with the window on screen, `pgrep -fl justsessions-test` on this Mac finds no `ssh` or `rsync` for the host. Quit and reopen: the host is still disconnected and lists its sessions without an `ssh`. **Connect** in ⋯ refreshes it at once, marks the kept session running, and the host refreshes on its own again within 5 minutes; after **Disconnect** once more, resuming a session there connects it the same way. |
| Refreshing on its own | With the app's window on screen, a session started on the host from Terminal is listed within about 5 minutes, without clicking Refresh, and coming back to the app after 5 minutes refreshes the host. With two windows open, only one `rsync` runs per refresh (`ps`), and both list the session. A host that is off waits longer after each failure. |
| Typing and Esc | With a tab open on the VM, `ps` shows its `ssh` with `-o ObscureKeystrokeTiming=no`, as does a Connect… login's `[mux]` master. `ssh justsessions-test tmux show-options -s escape-time` prints `escape-time 10`, and Esc stops Claude Code at once. |
| Shift and arrows | `JUSTSESSIONS_LIVE_SSH_HOST=justsessions-test swift test --filter LiveSSHTmuxModifiedNavigationKeyTests` passes for both engines: arrows, Home, and End with Shift, Option, or Control reach a CLI in the VM's tmux as xterm sends them. |
| Shift-Return and Control keys | `JUSTSESSIONS_LIVE_SSH_HOST=justsessions-test swift test --filter LiveSSHTmuxShiftReturnTests` passes for both engines on the VM's tmux 3.4, and with `rctest@justsessions-test`, whose login PATH puts a tmux 3.7c first (`/opt/tmux-3.7c`, linked from `~/.local/bin/tmux`). In a Claude Code, Pi, or OpenCode tab on the VM, Shift-Return adds a line to the prompt instead of sending it, and `ssh justsessions-test tmux show-options -s extended-keys` prints `extended-keys on`. |
| Focus tracking | Open a Claude Code tab on the VM with a real Claude Code, not the mock. No `tmux focus-events off` hint shows under its prompt, and `tmux show-options -s focus-events` on the host says `on`. |
| Codex activity | Start a Codex session on the VM. Its row and tab show the green dot once Codex is ready, the turning arc during a turn, and the amber mark while it waits for approval, such as for `touch ~/codex-approval-test`, which writes outside the project; with the app in the background, a turn's end and the approval wait each notify. `ssh justsessions-test tmux show-options -t <session>` lists `set-titles on`. Codex 0.128 or later is needed for the approval wait. |
| Claude Code live names | In a Claude Code tab on the test host, use `/rename` with spaces, quotes and Unicode. The tab and row take the new name without Refresh, while a name set in JustSessions still wins. `/clear` follows the new session on that host, keeps its CLI-chosen name, and renames the tmux session. A copy of the same session on another host keeps its own name. End and resume a CLI started before the live-name relay update; reattaching alone doesn't replace the relay. |
| Claude Code activity | Start a Claude Code session on the VM with a real Claude Code, not the mock. Its row and tab show the green dot once it is ready, the turning arc during a turn (or a `!sleep 4`), and the amber mark while a permission prompt or a dialog such as `/config` is open; with the app in the background, a turn's end and the wait each notify, and the finished turn keeps the blue dot. `ssh justsessions-test tmux show-options -w -t <session> @justsessions-activity` shows the record's status. Close the tab with **Keep running**, change the state, and reopen it: the tab shows the new state at once. **End session** leaves no `sh -c (` relay in `ps -u <user>`. |
| Pi and OpenCode activity | Start a Pi and an OpenCode session on the VM, each with a model it can reach. Each row and tab shows the green dot once it is ready, the turning arc during a turn, and the amber mark while OpenCode asks a permission (`"permission": {"bash": "ask"}` in its config) or a Pi extension's `ctx.ui.confirm` prompt is open; with the app in the background, a turn's end and the wait each notify. `ssh justsessions-test tmux show-options -w -t <session> @justsessions-activity` shows `working:`, `waiting:…`, or `idle:`, and `~/.cache/justsessions/live-session-reporting/pi` and `…/opencode` hold the extension. OpenCode's `/new` puts its own title back. Repeat with a fish login shell. With `~/.cache` a file, both CLIs still start. |
| A session with no tab | Close a Claude Code or Codex tab on the VM with **Keep running**, then start a turn in it from `ssh justsessions-test tmux attach -t <session>` and detach. Within a few seconds its row shows the turning arc, then the green dot, and with the app in the background the turn's end notifies. Ending the CLI there stops its row counting as running before the next refresh. |
| Kiro CLI activity | Start a Kiro CLI 2.31.1 or later session on a host, such as `justsessions-kiro`, and give it a prompt that takes a while. Its row and tab show the turning arc, then the green dot once the turn ends, or within about a second of Esc or Ctrl-C cancelling it, and with the app in the background the turn's end notifies. `ssh <host> ls ~/.local/share/kiro-cli/run/turn-markers` lists a marker only during the turn. |
| Antigravity activity | Resume an Antigravity session on a host with `python3`, such as `justsessions-agy`. Its row and tab show the green dot at once, the turning arc during a turn, and the amber mark while a command waits for approval; with the app in the background, both notify. Close the tab with **Keep running** and give it a prompt from `ssh <host> tmux attach`: the row still follows it. |
| Windows host | Adding the PowerShell user says it runs Windows and points to WSL; **Add anyway** shows the same on its heading, and no shell startup check runs for it. |
| Discovery and refresh | The installed provider is offered; the new session appears under the remote project and its preview matches the remote history. |
| Launch and resume | New sessions and resumed sessions run in the VM's project, including its space-containing path. Branch only where the provider supports it. |
| A CLI that fails as it starts | Give a tool the start command `sh -c 'echo Starting; exit 127'`, or leave `node` off the login shell's `PATH` for a Node CLI. Resuming one of its sessions ends the tab showing the error and **Exited (127)**, and `tmux ls` on the VM lists no session for it. With tmux older than 3.2 first on the login shell's `PATH`, the tab shows only `[exited]`. |
| CLI as an alias, a function, or in an install folder | For the bash and the fish user: with an alias that adds a flag, then a function, for the CLI in the startup file, **Check this host…** says so and passes, and a new tab's CLI has the flag (`ps -o args`). With the CLI only in `~/.claude/local` and that folder off the PATH, New session offers it and the tab starts it from there. **Close and delete session…** on a session started through the alias ends it and deletes it. |
| Keep running and reconnect | Close a running CLI tab with **Keep running**, then reattach to the same process and session. Also test interruption of just the SSH connection when changing reconnect behavior. Keep the VM running throughout. |
| Plain terminal | A terminal opens in the remote project, in tmux where the VM has it. Ending its tab's `ssh` reconnects it to the same shell (`#{pane_pid}` unchanged), and so does quitting and opening the app again. ⌘F finds text that scrolled off the screen; it shows the count with `rctest`'s 3.7c and none with the VM's 3.4, which counts nothing. Closing its tab, or quitting with **Reopen tabs** off, ends the shell and its tmux session. Check `history_limit` on the VM's tmux 3.4 (the host's own) and with `rctest@justsessions-test`'s 3.7c (10000). |
| Dropping files | In both terminal engines, drop an image and a file whose name has spaces on a Claude Code or Codex tab and on a plain terminal on the VM. Each path typed is under `~/.cache/justsessions/dropped-files` and the file there matches. Drop a file of a few hundred MB: the corner shows progress, and **Cancel** types nothing and leaves no copy. A folder is refused with a note. Stopping the VM mid-copy says the connection was lost. |
| Light/dark switch | With a Claude Code tab open on the VM, whose tmux 3.4 predates theme reports, switch the app between a light and a dark theme. The tab's text keeps a readable contrast at once, and Claude Code redraws its screen in the new colors about 2 seconds later. Scrollback above the screen keeps the old colors. |
| Deletion | Delete a disposable session and verify it disappears both on the VM and after refresh. Exercise batch deletion, cancel, and retry when those paths change. |
| Unavailable host | After finishing the persistence check, stop the VM and refresh. Verify the failure is reported, then start the VM, check its IP, and verify recovery. |

A VM shutdown ends its processes; restarting it is an unavailable-host test, not proof that tmux survives an SSH disconnect. For an actual connection-interruption check, end only the test tab's SSH client process and reconnect; confirm the remote tmux pane PID and running CLI are unchanged. Avoid commands that kill all SSH clients or all tmux sessions.

Record the pane PIDs of the app's tmux sessions on the VM before and after the interruption:

```sh
ssh justsessions-test 'tmux list-panes -a -F "#{session_name} #{pane_pid} #{pane_current_command}" | grep "^justsessions-"'
```

Tabs connect with `/usr/bin/ssh -t`; refreshes and history mirroring connect without `-t`, so this lists only the host's tabs. Pick the test tab's PID and end that one process:

```sh
pgrep -fl '^/usr/bin/ssh -t .*justsessions-test'
kill PID
```

## macOS target coverage

Create a dedicated standard macOS test account with disposable projects and CLI history. Enable **System Settings → General → Sharing → Remote Login** for that account, following [Apple's Remote Login guide](https://support.apple.com/guide/mac-help/allow-a-remote-computer-to-access-your-mac-mchlp1066/mac). For a target on the development Mac, connect to `test-account@127.0.0.1`.

Authorize your test public key in that account's `~/.ssh/authorized_keys`, with permissions `700` for `.ssh` and `600` for `authorized_keys`. Give it a separate SSH alias such as `justsessions-test-macos`, with `User` set to the test account and the same local `IdentityFile`, `AddKeysToAgent`, and `UseKeychain` settings. Verify a batch-mode SSH connection before adding it to JustSessions. Install the selected CLI and remote dependencies for that account, check their availability in its login shell, and repeat the relevant checklist. This covers macOS paths, its default shell, and differences between BSD and GNU command-line tools.

## Evidence and cleanup

In the PR's manual-check section, record the tested commit, Mac and target OS versions, target architecture, provider and CLI version, `tmux -V`, and each check's result. Mark untested providers, macOS targets, and network-interruption cases explicitly. Fixtures, simulated hosts, and `make verify` provide separate evidence; they do not establish a live provider login or SSH connection.

Run the usual `make verify` on the final commit before submitting. This guide adds manual SSH coverage for relevant changes; it does not change that required check.

Stop the VM when finished:

```sh
multipass stop justsessions-ssh-test
```

To permanently discard this test environment, first remove its host from JustSessions and sign out of any provider accounts if needed, then run `multipass delete --purge justsessions-ssh-test`. That command destroys this VM's projects, sessions, and credentials. Remove its SSH config block and dedicated known-host entry when you no longer need the alias. Keep private keys and provider credentials out of the repository.
