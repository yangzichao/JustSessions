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

## Configure passwordless SSH

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

Check the VM's host-key fingerprint through Multipass, then make the first SSH connection interactively. Accept the host key only when its fingerprint matches. The final command must succeed without asking for a password or passphrase; that is the mode the app needs.

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
ssh -o BatchMode=yes justsessions-test 'exec "$SHELL" -lic "command -v claude && claude --version"'
```

Without a terminal, bash first prints `cannot set terminal process group` and `no job control in this shell`; those two lines are expected. Substitute the executable for the provider being tested. Keep its session storage at the locations documented in [session storage](../guides/session-storage.md#ssh-session-cache). `rsync` is required for history mirroring; Antigravity and OpenCode also require `python3`, and Antigravity deletion requires `lsof`. Remote persistence uses the VM's `tmux`, not the app's bundled Mac binary.

The VM has a local network address, so on macOS 15 and later JustSessions needs Local Network access to reach it, as for any SSH host on your network; see **Settings → Permissions**. In JustSessions, choose **Add SSH host…**, enter `justsessions-test`, then add `/home/ubuntu/justsessions-test/project with spaces` under that host. Start a small disposable conversation so the host has real session history to discover and preview.

## Manual checks for an SSH change

Run the checks relevant to the change and record the result of each:

| Check | What to verify |
| --- | --- |
| Discovery and refresh | The installed provider is offered; the new session appears under the remote project and its preview matches the remote history. |
| Launch and resume | New sessions and resumed sessions run in the VM's project, including its space-containing path. Branch only where the provider supports it. |
| Keep running and reconnect | Close a running CLI tab with **Keep running**, then reattach to the same process and session. Also test interruption of just the SSH connection when changing reconnect behavior. Keep the VM running throughout. |
| Plain terminal | A terminal opens in the remote project and closing its tab ends that shell, as described in the user guide. |
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
