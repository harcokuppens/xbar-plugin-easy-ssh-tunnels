## Establishing SSH Tunnels from Xbar: A Deep Dive into `expect` and `nohup`

This document details the challenges and solutions encountered when establishing SSH
tunnels from an xbar menu, particularly focusing on the interaction between `expect`,
`ssh`, and the macOS `launchd` service.

### The Goal: Automated SSH Tunneling via Xbar

We aim to initiate an SSH tunnel from an xbar menu. To automate the SSH connection's
authentication (password/OTP), we utilize an `expect` wrapper script. Given that GUI
commands need to be processed quickly to maintain responsiveness, our initial
approach involved using the `ssh -f` option, which sends SSH to the background after
authentication, allowing the command to return immediately.

**Initial Command Attempt (Command 1):**

```bash
expect_passwd_and_otp -p keychain_password -o keychain_otp_code sshtunnel -f 12345 lilo8.science.ru.nl cup.cs.ru.nl 1080
# -> The expect script exits with 'exit 0' after authentication.
```

### Problem 1: `expect ssh -f` Fails with ProxyJumps

When using `ssh -f` within an `expect` script, especially with `ProxyJump`
configurations, the tunnel fails.

**Detailed Problem Description:**

The core issue is that `ssh -f` detaching within a pseudo-terminal (PTY) created by
`expect`'s `spawn` command triggers a specific behavior in macOS's `launchd`. When
`ssh -f` detaches, `launchd` interprets the termination of this PTY's primary process
(SSH) as a "hang-up" event for that temporary interactive context. Consequently,
`launchd` initiates its cleanup policy, sending a `SIGHUP` signal that kills all
forked and descendant processes, including the SSH tunnel itself. This doesn't occur
when `ssh -f` is run directly in an existing terminal, as it inherits a persistent
PTY, and `launchd` doesn't intervene.

For more details see the section "Understanding `ssh -f` Behavior with ProxyJump: The
PTY's Context" below.

### Fix 1: Using `expect`'s `interact` Instead of `exit 0`

To prevent `launchd` from sending `SIGHUP` signals, we run `ssh` without the `-f`
option keeping it in the foreground and handle it using `expect`'s `interact` command
instead of `exit 0` at the end of the `expect` script. This hands over the PTY
created by `spawn` to the `expect` process itself, keeping the SSH process alive.

**Revised Command (Command 2):**

```bash
expect_passwd_and_otp -p keychain_password -o keychain_otp_code sshtunnel 12345 lilo8.science.ru.nl cup.cs.ru.nl 1080
# -> The expect script uses 'interact' at the end.
```

### Problem 2: `expect`'s `interact` Fails in Non-PTY Environments (like xbar)

While `interact` works in a standard terminal, it fails when the `expect` script is
launched from a non-PTY environment, such as an xbar menu command, which is typically
executed via `launchctl`.

**Detailed Problem Description:**

`interact` requires stdin and stdout to be connected to a fully functional
interactive terminal (PTY). In a non-PTY environment like xbar/`launchctl`, there is
no terminal for `expect` to "interact" with. Consequently, `interact` immediately
returns with an EOF debug message (`interact: received eof from spawn_id exp0`),
signifying that the `expect`'s execution environment lacks a PTY. When `interact`
fails, the `expect` script exits, and `launchd` sends a `SIGHUP` to all its children,
including the SSH process, effectively killing the tunnel.

**Excerpt from xbar log:**

```
...
2025-06-10 16:38:49 toggle_tunnel:  interact: received eof from spawn_id exp0      -> interact cannot handover cmd to expect's pty because  execution environment does not have pty -> therefore got eof from expect's exec. env !!
2025-06-10 16:38:49 toggle_tunnel:  Expect: ended , because  interact ended by failed handover
...
```

### Final Fix 2: Protecting SSH with `nohup`

The definitive solution involves using the `nohup` command before the `ssh` command
within the `expect` script. `nohup` prevents the `SIGHUP` signal from reaching `ssh`,
ensuring the tunnel remains active even if the `expect` process exits.

**Explanation of `nohup`'s Role:**

- `nohup` rebinds stdin to `/dev/null` and stdout/stderr to a `nohup.out` file,
  ensuring SSH doesn't require interaction with a PTY after authentication.
- Crucially, `nohup` catches `SIGHUP` signals, preventing `launchd` (or `expect`'s
  exit) from killing the SSH process.
- Because `nohup` protects SSH, the `expect` script can simply use `exit 0` at its
  end. Even if `interact` were used and failed in the xbar context, the SSH tunnel
  would persist due to `nohup`.

**Working Command (Command 3):**

```bash
expect_passwd_and_otp -p keychain_password -o keychain_otp_code nohup sshtunnel 12345 lilo8.science.ru.nl cup.cs.ru.nl 1080
# -> The expect script can now use 'exit 0' (or even 'interact' which will fail but won't kill SSH).
```

This command works reliably in both terminal environments and when launched via
`launchctl` from xbar.

**Additional Note:** Applying `nohup` to the initial `ssh -f` approach (Command 1)
would also work, as `nohup` would make SSH immune to the `SIGHUP` from `launchd` when
`ssh -f` detaches.

```bash
expect_passwd_and_otp -p keychain_password -o keychain_otp_code nohup sshtunnel -f 12345 lilo8.science.ru.nl cup.cs.ru.nl 1080
# -> The expect script exits with 'exit 0' at the end.
```

### Why `nohup expect` Doesn't Work (Command 4):

Placing `nohup` _before_ the `expect` command does not solve the problem.

**Failed Command (Command 4):**

```bash
nohup expect_passwd_and_otp -p keychain_password -o keychain_otp_code sshtunnel 12345 lilo8.science.ru.nl cup.cs.ru.nl 1080
# -> The expect script uses 'exit 0' at the end.
```

This fails because `expect` itself, when run within a `nohup` environment, still
operates in a non-PTY context. If the `expect` script attempts to use `interact`, it
will immediately fail (`interact: received eof from spawn_id exp0`) because
`expect`'s own execution environment lacks a PTY. Although `nohup` would protect the
`expect` process from `SIGHUP`, the core issue of `interact`'s PTY requirement
remains, leading to the `expect` script's premature exit and subsequent `SIGHUP` to
its children (including SSH). The critical difference is where `nohup` is applied: it
must protect the SSH process directly, not the `expect` wrapper that orchestrates its
launch.

### Understanding `ssh -f` Behavior with ProxyJump: The PTY's Context

The behavior of `ssh -f` with `ProxyJump` differing inside and outside of `expect`
stems from how `launchd` on macOS manages processes based on the PTY's context.

- **Ephemeral `expect`-managed PTY:** When `ssh -f` is launched by `expect`'s
  `spawn`, it uses a temporary PTY. If `ssh -f` detaches, `launchd` sees the PTY's
  primary user (SSH) terminate, leading to a "hang-up" event and a `SIGHUP` to
  cleanup associated processes.
- **Persistent Main Login Terminal PTY:** When `ssh -f` is run directly in a standard
  terminal, it inherits the terminal's persistent PTY. `launchd` recognizes that the
  main user session is still active, and detached processes continue to run in the
  background without being terminated by `SIGHUP`.

Therefore, the key is not an inherent operating system difference, but `launchd`'s
intelligent session cleanup rules, which vary based on the PTY's lifecycle and its
role within the overall user session. By using `nohup` directly on the `ssh` command
within the `expect` script, we effectively decouple the SSH tunnel's lifecycle from
the ephemeral nature of the `expect`-created PTY, allowing the tunnel to persist as
intended.
