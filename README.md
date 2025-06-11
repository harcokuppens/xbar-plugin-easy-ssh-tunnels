# easy-ssh-tunnels: Effortless SSH Tunnels & Proxies for macOS (xbar Plugin)

**easy-ssh-tunnels** is a plugin for [xbar](https://xbarapp.com/) that lets you
quickly set up SSH tunnels and SOCKS proxies from the macOS menu bar. It is designed
for users who need secure, flexible, and convenient access to remote
services—especially when two-factor authentication (2FA) is required.

This plugin leverages the
[`sshtunnel`](https://github.com/harcokuppens/easysshtunnel) and
[`sshbridge`](https://github.com/harcokuppens/easysshtunnel) scripts for logical,
readable SSH tunnel commands, and wraps them with interactive or automated
authentication using `expect`. You can configure tunnels and proxies in a simple JSON
file, and monitor or control them directly from your menu bar.

---

<!--ts-->
<!-- prettier-ignore -->
   * [<strong>Features</strong>](#features)
   * [<strong>Goal</strong>](#goal)
   * [<strong>Installation</strong>](#installation)
   * [<strong>Configuration</strong>](#configuration)
      * [<strong>1. Ssh commands made easy</strong>](#1-ssh-commands-made-easy)
      * [<strong>2. tunnels.json</strong>](#2-tunnelsjson)
      * [<strong>3. Authentication Wrappers</strong>](#3-authentication-wrappers)
         * [<strong>Default: Dialog Prompts</strong>](#default-dialog-prompts)
         * [<strong>Automated: macOS Keychain</strong>](#automated-macos-keychain)
      * [<strong>4. Timeout Settings</strong>](#4-timeout-settings)
   * [<strong>Usage</strong>](#usage)
   * [<strong>Advanced: Custom Authentication</strong>](#advanced-custom-authentication)
   * [<strong>How it Works</strong>](#how-it-works)
   * [<strong>Credits</strong>](#credits)
   * [<strong>Troubleshooting</strong>](#troubleshooting)
   * [<strong>License</strong>](#license)
<!--te-->

---

## **Features**

- **One-click SSH tunnels and proxies** from the macOS menu bar.
- **2FA/OTP and password support**: Dialogs prompt only when needed, or use secrets
  from the macOS Keychain.
- **Flexible configuration**: Add or edit tunnels in `tunnels.json`.
- **Detailed logging**: All actions and errors are logged to `easy-ssh-tunnels.log`,
  accessible from the menu.
- **Customizable authentication**: Use dialog prompts, or scripts to fetch
  credentials from the Keychain.
- **Logical SSH command syntax**: Uses `sshtunnel` and `sshbridge` for clear,
  readable tunnel definitions.

---

## **Goal**

The goal of **easy-ssh-tunnels** is to make secure SSH tunnels and proxies as easy as
possible to use, while supporting advanced authentication scenarios (like 2FA) and
providing a clear, maintainable configuration. It is especially useful for users who
frequently need to access remote desktops, internal services, or SOCKS proxies
through jump hosts and firewalls.

---

## **Installation**

1. **Install xbar**  
   Download and install [xbar](https://xbarapp.com/) if you haven't already.

2. **Clone or Download this Repository**  
   Download or clone the contents of this repository to your computer.

3. **Copy to xbar Plugins Folder**  
   Move the entire folder (for example, `easy-ssh-tunnels`) into your xbar plugins
   directory.  
   The plugins folder is usually at:

   ```
   ~/Library/Application Support/xbar/plugins/
   ```

   After copying, you should have:

   ```
   ~/Library/Application Support/xbar/plugins/easy-ssh-tunnels.30s.sh
   ~/Library/Application Support/xbar/plugins/easy-ssh-tunnels/
   ```

   (with all the scripts and subfolders inside)

4. **Install Dependencies**

   - [Homebrew](https://brew.sh/) (if not already installed)
   - Install required tools:
     ```sh
     brew install jq gawk oath-toolkit
     ```
   - xbar will also need access to `expect` (usually pre-installed on macOS).

5. **(Optional) Install `sshtunnel` and `sshbridge` globally**  
   The plugin includes its own copies, but you can also install or update them from
   [easysshtunnel](https://github.com/harcokuppens/easysshtunnel).

---

## **Configuration**

### **1. Ssh commands made easy**

The `ssh` command is a great tool to make SSH tunnels for either

- **tunneling**: making an end-to-end encrypted tunnel to protect data traffic which
  is send through it from eavesdropping
- **bridging**: setup an SSH connection to a bridge SSH server to bridge data traffic
  over a firewall to a server behind it

However the syntax for the `ssh` command to implement above cases is a bit tricky in
details. Everytime I want to setup such connection I have to figure out the details
again, which costs me a lot of time everytime.

Therefore I decided to make 2 simple wrapper commands over the `ssh` command to make
it more easy and intuitive to create a new SSH tunnel or bridge within a few seconds:

1. [sshtunnel](https://github.com/harcokuppens/easysshtunnel#sshtunnel) - create an
   end-to-end encrypted SSH tunnel from a local port on localhost to a local port on
   a SSH server
2. [sshbridge](https://github.com/harcokuppens/easysshtunnel#sshbridge) - use SSH to
   bridge TCP traffic over a firewall.

These commands are more intuitive because their arguments specify the linear order in
which the data is flowing. So by just thinking how you want the traffic to go, you
can just immediately write out the command.

### **2. tunnels.json**

All tunnels and proxies are defined in `easy-ssh-tunnels/tunnels.json`.  
Each entry specifies:

- `PORT`: Local port to listen on.
- `LABEL`: Description shown in the menu.
- `TYPE`: `"local"` for port forwards, `"dynamic"` for SOCKS proxies.
- `EXPECT_WRAPPERS`: How to handle authentication (see below).
- `COMMAND`: The actual tunnel command (using `sshtunnel`, `sshbridge`, or `ssh`).

**Example:**

```json
{
  "DEFAULT_TIMEOUT": 30,
  "TUNNELS": [
    {
      "PORT": 13389,
      "LABEL": "RDP to windows laptop",
      "TYPE": "local",
      "EXPECT_WRAPPERS": "expect_passwd_and_otp -p keychain_password -o keychain_otp_code",
      "COMMAND": "sshbridge 13389 bridge.example.com windows.internal 3389",
      "TIMEOUT": 5
    },
    {
      "PORT": 1080,
      "LABEL": "SOCKS Proxy via bridge.example.com",
      "TYPE": "dynamic",
      "EXPECT_WRAPPERS": "expect_passwd_and_otp",
      "COMMAND": "ssh -N -D 1080 user@bridge.example.com"
    },
    {
      "PORT": 12345,
      "LABEL": "SSH tunnel MyTunnel configured in ~/.ssh/config",
      "TYPE": "local",
      "EXPECT_WRAPPERS": "expect_passwd_and_otp -p keychain_password -o keychain_otp_code",
      "COMMAND": "ssh MyTunnel",
      "TIMEOUT": 5
    }
  ]
}
```

Note that for proxies we use the standard **ssh** command, because for proxies its
command syntax is fine.

We can also uses as `COMMAND` something like `ssh MyTunnel` where `MyTunnel` is a
preset configuration in your `~/.ssh/config` configuration file. Eg.

```shell
$ cat ~/.ssh/config
Host MyTunnel
    User henk
    HostName windows.internal
    Port 22
    ProxyJump bridge.example.com:22
    LocalForward localhost:12345 localhost:80
    # the  -N option is done in the config with
    SessionType none
```

The `SessionType none` should be added in your config, otherwise when closing the
tunnel with this xbar plugin, which is done with a kill to the PID of ssh tunnel
process, you will get an error dialog because the session exited suddenly. If there
is only a tunnel without a session the tunnel will terminate without an error, and
you won't get an error dialog.

### **3. Authentication Wrappers**

#### **Default: Dialog Prompts**

By default, the plugin uses dialog windows to prompt for passwords and OTP codes only
when needed.  
This is handled by the `expect_passwd_and_otp` wrapper, which calls:

- `dialog_password` (asks for password)
- `dialog_otp_code` (asks for OTP/2FA code)

#### **Automated: macOS Keychain**

You can automate authentication by storing secrets in the macOS Keychain and using:

- `keychain_password` (fetches password) **IMPORTANT:** instead of using a password I
  highly recommend to use a public/private key pair which you install in your ~/.ssh
  folder.
- `keychain_otp_code` (fetches OTP secret and generates current code)

**IMPORTANT notes:**

**To set up:**

1. **Store your SSH password in the Keychain:**

   ```sh
   SERVICE_NAME="xbar_easy_ssh_tunnels"
   ACCOUNT_NAME="password"
   security add-generic-password -l "$SERVICE_NAME ($ACCOUNT_NAME)" -s "$SERVICE_NAME" -a "$ACCOUNT_NAME" -T "" -w
   ```

   You will be prompted to enter the password.

2. **Store your OTP secret in the Keychain:**

   ```sh
   SERVICE_NAME="xbar_easy_ssh_tunnels"
   ACCOUNT_NAME="otp_secret"
   security add-generic-password -l "$SERVICE_NAME ($ACCOUNT_NAME)" -s "$SERVICE_NAME" -a "$ACCOUNT_NAME" -T "" -w
   ```

   Enter your TOTP secret (the base32 string, not the current code).

3. **Configure your tunnel in `tunnels.json`:**
   ```json
   "EXPECT_WRAPPERS": "expect_passwd_and_otp -p keychain_password -o keychain_otp_code"
   ```
   This tells the wrapper to use the keychain scripts for both password and OTP.

**Note:**

- The first time you use these scripts, macOS will ask for permission to allow access
  to the Keychain item.
- If you click "Always Allow", you won't be prompted again.
- Not all tunnels use the same credentials. To tackle this we can create multiple
  different `keychain_password/keychain_otp_code` scripts to supply multiple
  different authentication credentials. Each script should use internally a different
  `ACCOUNT_NAME` in the keychain to prevent conflicts. Eg. create a
  `keychain_otp_code_myservice` with `ACCOUNT_NAME="otp_secret_myservice"`.

### **4. Timeout Settings**

The plugin supports both a **global timeout** and a **per-tunnel timeout** for
starting SSH tunnels. This timeout determines how long the plugin will wait for a
tunnel to successfully start before considering it failed. A special timeout of 0
means wait forever until the ssh command itself exits.

- **Global Timeout:**  
  You can set a default timeout value that applies to all tunnels. This is useful for
  general cases and can be configured in the main plugin script or configuration. You
  specify the global timeout in the `DEFAULT_TIMEOUT` field in root object in the
  `tunnels.json`.

- **Per-Tunnel Timeout:**  
  You can override the global timeout for individual tunnels by specifying a
  `TIMEOUT` field in the tunnel's entry in `tunnels.json`.

**Example:**

```json
[
  {
    "PORT": 13389,
    "LABEL": "RDP to windows laptop",
    "TYPE": "local",
    "EXPECT_WRAPPERS": "expect_passwd_and_otp -p keychain_password -o keychain_otp_code",
    "COMMAND": "sshbridge 13389 bridge.example.com windows.internal 3389",
    "TIMEOUT": 5
  }
]
```

**Best Practices:**

- For tunnels using **automated authentication** (such as keychain scripts), use a
  **short timeout** (e.g., 3–5 seconds), since these tunnels should start almost
  instantly. If they do not, a quick timeout helps detect issues early.
- For tunnels requiring **manual authentication** (dialogs), you may want to use a
  longer timeout to allow time for user input.
- If a tunnel gives problem, then to debug set the `"TIMEOUT": 0` so that the ssh
  command can run itself to its end giving us more information about what is going
  wrong.

If a tunnel fails to start within the specified timeout, it will be marked as failed
and the error will be logged in `easy-ssh-tunnels.log`.

---

## **Usage**

- **Menu Bar:**  
  After installation, you'll see a cloud icon in your menu bar.

  - Green with a superscript number: active tunnels.
  - Black: no active tunnels.

- **Start/Stop Tunnels:**  
  Click a menu item to toggle a tunnel or proxy on/off.

  - If authentication is needed, dialogs will appear (unless using keychain scripts).

- **View Logs:**  
  The menu provides a shortcut to open `easy-ssh-tunnels.log` for troubleshooting.

- **Edit Configuration:**  
  The menu also lets you open `tunnels.json` for quick editing.

---

## **Advanced: Custom Authentication**

You can create your own scripts for password or OTP retrieval and specify them in
`EXPECT_WRAPPERS`:

```json
"EXPECT_WRAPPERS": "expect_passwd_and_otp -p my_custom_password_script -o my_custom_otp_script"
```

---

## **How it Works**

- The plugin reads `tunnels.json` and builds the menu dynamically.
- When you start a tunnel, it uses the specified wrapper to handle authentication.
- Tunnels are started in the background and monitored for status.
- All output and errors are logged to `easy-ssh-tunnels.log`.
- The menu updates automatically as tunnels start/stop.

---

## **Credits**

- **sshtunnel** and **sshbridge** scripts:
  [easysshtunnel](https://github.com/harcokuppens/easysshtunnel)
- Plugin author: [Harco Kuppens](https://github.com/harcokuppens)

---

## **Troubleshooting**

- Make sure you have `jq`, `gawk`, `oathtool`, and `expect` installed. The `expect`
  tool comes with MacOS, but the other tools you can install with homebrew:

  ```sh
  brew install jq gawk oath-toolkit
  ```

- Check `easy-ssh-tunnels.log` for errors.
- If tunnels do not start, verify your SSH config and credentials.

---

## **License**

MIT License (see [easysshtunnel](https://github.com/harcokuppens/easysshtunnel) for
details on included scripts).

---

Enjoy secure, convenient SSH tunnels and proxies—right from your Mac menu bar!
