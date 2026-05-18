# Habbo (AIR desktop build)

A Windows desktop build of the Habbo Flash client packaged as a Harman AIR captive-runtime app, so the hotel runs without a browser Flash plugin.

The window title, icon, and bundle naming mirror the official HabboWin look. The AIR application ID is deliberately `com.habbo.air` (not the official `com.sulake.habboair`) — coexists cleanly with the real Sulake client on the same machine and avoids impersonating their publisher identity.

---

## Compatible client source

This project compiles **exclusively** against the `feature-air` branch of `habbo-cc/habbo-client-cc`. The AIR root class (`HabboAir.as`), the `HabboWebTools` parameter bridge, the AIR-aware login dialog and a handful of other AIR-specific patches **only exist on that branch**. Compiling against any other branch will fail.

- Branch: <https://github.com/habbo-cc/habbo-client-cc/tree/feature-air>
- Pinned commit: [`0c0f1c4db`](https://github.com/habbo-cc/habbo-client-cc/commit/0c0f1c4db) — *Add AIR desktop support (HabboAir root SWF + companion fixes)*

This is the same AIR commit that lives on the `ngh-air` branch (`ee11459a5`), cherry-picked onto `feature-branch`. It carries every AIR change but none of the NGH-specific theming.

Clone the client like this (the `build.bat` defaults to `C:\habbo\client\habbo-client-clean`):

```bat
git clone --branch feature-air https://github.com/habbo-cc/habbo-client-cc.git C:\habbo\client\habbo-client-clean
```

---

## Relationship to other branches in this repo

| Branch | App name | Client branch | Icons | Notes |
| --- | --- | --- | --- | --- |
| `ngh` | NGHWin | `habbo-cc:ngh-air` | Custom NGH pixel-art | NGH-flavoured build with NGH theming via the underlying client branch |
| `habbo` (this branch) | Habbo | `habbo-cc:feature-air` | Official Habbo icons | Neutral build without NGH-specific catalog/window-manager theming |

---

## Repository layout

```
Habbo/
├── README.md
├── build.bat            # compile + package script (compile|package|run|cert|clean)
├── config.ini           # runtime endpoint/host/port config (staged into bundle)
├── cert.p12             # self-signed signing cert (replace before redistributing)
├── icons/               # 16/32/48/128 official Habbo icons + source.png
├── build/               # staged AIR files: descriptor + HabboAir.swf + local_include
└── HabboBundle/         # packaged captive-runtime output: Habbo.exe + Adobe AIR/ + assets
```

The companion Habbo client lives at `C:\habbo\client\habbo-client-clean` and is **not** part of this repo; override with the `CLIENT_DIR` env var if you have it elsewhere.

---

## Prerequisites

| Tool | Where | Override env var |
| --- | --- | --- |
| Harman AIR SDK 51.3.1 (Windows) | `C:\harman-air\AIRSDK_51.3.1` | `AIR_HOME` |
| Java JDK 21 | `C:\Program Files\Java\jdk-21` | `JAVA_HOME` |
| Apache Flex SDK | `C:\flex` | (used implicitly by the clean-client npm tool) |
| habbo-client-cc `feature-air` checkout | `C:\habbo\client\habbo-client-clean` | `CLIENT_DIR` |
| Gordon production assets | `C:\habbo\ngh\gordon\PRODUCTION-201611291003-338511768` | `GORDON_DIR` |

Get the AIR SDK from <https://airsdk.harman.com>.

The Gordon directory must contain the six core room SWFs that get bundled locally:

- `HabboRoomContent.swf`
- `PlaceHolderFurniture.swf`
- `PlaceHolderWallItem.swf`
- `PlaceHolderPet.swf`
- `TileCursor.swf`
- `SelectionArrow.swf`

These are the files the AIR build resolves as `app:/local_include/<name>.swf` at runtime.

You also need the clean-client's Node.js tooling working — `npm install` inside `C:\habbo\client\habbo-client-clean` once is enough.

---

## Building

From any working directory:

```bat
cmd.exe /c "C:\habbo\apps\NGHWin\build.bat"
```

Targets:

```bat
build.bat compile       # compile HabboAir.swf + stage local_include + config.ini + icons
build.bat package       # package the Windows captive-runtime bundle into HabboBundle\
build.bat run           # run with ADL straight from build\ (dev mode, no packaging)
build.bat cert          # one-time: regenerate cert.p12 if you deleted it
build.bat clean         # remove build/ and bundle/ outputs
build.bat               # default: compile + package
```

What `compile` actually runs:

```text
npm run tool -- build \
  --source src/HabboAir.as \
  --output <PROJECT_DIR>/build/HabboAir.swf \
  --bin <PROJECT_DIR>/build \
  --no-archive \
  -- -external-library-path+=<AIR_HOME>/frameworks/libs/air/airglobal.swc
```

After that, `build.bat`:

1. Stages the six local-include room SWFs from `GORDON_DIR` into `build/local_include/`
2. Stages `config.ini` from the repo root into `build/`
3. Stages icons from `icons/icon-{16,32,48,128}.png` into `build/icons/`

`package` then runs `adt -package … -target bundle HabboBundle build/application.xml -C build .` against the staged tree.

If packaging fails because `Habbo.exe` is still running:

```powershell
Get-Process -Name Habbo -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

## Runtime architecture

```text
Habbo.exe
  └─ AIR captive runtime loads HabboAir.swf
       └─ HabboAir.as bootstraps:
          1. parses CLI args (-ticket / -host / -port / -account / -server)
          2. reads app:/config.ini, then app-storage:/config.ini
          3. fills the AIR parameter dictionary the rest of the client expects
             (connection.info.host, site.url, external.*, flash.client.url, etc.)
          4. sets HabboWebTools.isAirDesktop = true
          5. assigns HabboWebTools.airParameters + rootLoaderInfo
          6. configures flash.net.URLRequestDefaults with browser headers
          7. shows the loading screen, then constructs HabboMain
       └─ HabboMain inits the Core + components
          - HabboConfigurationManager reads via HabboWebTools.getParameter
          - BitmapFileLoader fetches c_images with browser-style headers
          - RoomContentLoader resolves the 6 core SWFs from app:/local_include/
          - HabboCommunicationDemo opens the AIR SSO dialog (no -ticket case)
       └─ User pastes SSO ticket → Login
          - Socket connects to connection.info.host:port
          - Diffie handshake → SSO sent → server responds
          - On AuthOK: dialog/bg torn down, loading screen restored, world loads
          - On failure: status text updates, 1s cooldown, button re-enabled
```

All AIR-specific code paths in the client are gated on `HabboWebTools.isAirDesktop`, so the browser SWF behaviour is unchanged.

---

## Runtime config (`config.ini`)

`config.ini` is read at startup; edit + relaunch with no SWF recompile.

Precedence (highest wins):

1. CLI args (`-ticket`, `-host`, `-port`, `-account`)
2. `app-storage:/config.ini` (per-user override at `%APPDATA%\com.habbo.air\Local Store\config.ini`)
3. `app:/config.ini` (shipped in `HabboBundle\config.ini`)
4. Hardcoded `DEFAULT_*` consts in [`src/HabboAir.as`](https://github.com/habbo-cc/habbo-client-cc/blob/feature-air/src/HabboAir.as)

File format: `key=value` per line, `#` or `;` for comments, UTF-8.

Two shorthand keys derive the rest:

- `base.url` — substituted into every derived URL (`external.*`, `furnidata.load.url`, `productdata.load.url`, `flash.client.url`, etc.) unless overridden.
- `gordon.path` — appended to `base.url` to form `flash.client.url`.

Any other AIR parameter key can be set directly to bypass the `base.url` shorthand:

```text
connection.info.host
connection.info.port
site.url
url.prefix
client.reload.url
client.fatal.error.url
client.connection.failed.url
external.variables.txt
external.texts.txt
external.override.variables.txt
external.override.texts.txt
external.figurepartlist.txt
flash.dynamic.avatar.download.configuration
productdata.load.url
furnidata.load.url
flash.client.url
```

The shipped `config.ini` defaults to `127.0.0.1:3000,3001` — change `base.url`, `connection.info.host`, and `connection.info.port` for your hotel.

---

## CLI args

`HabboAir.as` accepts:

```text
-ticket <sso>     # pre-fill the SSO ticket (skips the in-client login window)
-host <host>      # override connection.info.host
-port <ports>     # override connection.info.port (comma-separated for fallback)
-account <id>     # set account_id / unique_habbo_id
-server <env>     # set environment.id
```

If no ticket is supplied, the in-client AIR login window appears after boot — paste the SSO ticket and click Login. The ticket persists between launches in the `fuselogin` SharedObject under `data.air_sso`.

---

## Local Include Assets

AIR bundles only the six core room SWFs that official HabboWin keeps local (everything else loads from URLs). They're copied from `GORDON_DIR` into `build/local_include/` during compile, then resolved at runtime as `app:/local_include/<name>.swf`.

`c_images` and everything else **must stay URL-driven**. Do not copy catalogue icons, room ads/backgrounds, variables, texts, or general Gordon assets into `local_include`.

---

## Remote bitmap loading

The AIR `c_images` blocker was `HTTP 403` responses to AIR's `Loader` even though the same URLs worked everywhere else. The fix (AIR-only, in [`BitmapFileLoader.as`](https://github.com/habbo-cc/habbo-client-cc/blob/feature-air/src/com/sulake/core/assets/loaders/BitmapFileLoader.as) on the `feature-air` branch):

- `HabboAir.as` primes `flash.net.URLRequestDefaults` before any client loading
- `BitmapFileLoader` sets `LoaderContext.checkPolicyFile = false` inside the AIR app sandbox
- Remote http(s) PNG/GIF/JPG requests are rewritten with browser-style `User-Agent`, `Accept`, `Referer` headers
- If a 403 still slips through, a binary `URLLoader` fetches the bytes and feeds them into `Loader.loadBytes`, preserving the original cache key

Browser flow is untouched.

---

## SSO login dialog

The compact SSO dialog ([`HabboCommunicationDemoCom_login_window.bin`](https://github.com/habbo-cc/habbo-client-cc/blob/feature-air/src/binaryData/HabboCommunicationDemoCom_login_window.bin)) replaces the stock 305×444 Habbo Login form with a 360×226 Ubuntu-themed dialog containing:

- Intro text explaining what an SSO ticket is
- Single `SSO Ticket:` input row (pre-filled from `SharedObject.data.air_sso` if previously used)
- Inline status text ("Connecting…" / error message)
- Login button

Behaviour:

- 1-second retry cooldown after every failure — button is only re-enabled by a Timer, so spam clicks can't queue overlapping connections
- AIR-specific re-entry guards in both `HabboLoginDemoView` and `HabboCommunicationDemo`
- `_communication.renewSocket()` is called before each AIR retry to reset `HabboCommunicationManager._connectionAttempts`, otherwise the comm manager runs out of port-retry budget after ~5 bad-SSO attempts and `Core.error()` disposes the comm component
- AIR error copy is hardcoded (not externalised through `${...}` keys) because external texts aren't loaded until after auth
- AIR background is only torn down when `onAuthenticationOK` fires — never on failure, so the SSO dialog always has a visible backdrop

---

## Diagnostics

The AIR build writes a small debug log at:

```text
%APPDATA%\com.habbo.air\Local Store\debug.log
```

It captures `onInitConnection`, `onAuthenticationOK`, `onGenericError`, `onConnectionDisconnected`, `onDisconnectReason`, `HabboCommunicationDemo.dispose`, and any uncaught error. Append-only — delete the file to start fresh.

---

## Toolchain summary

- Main client compiler: Apache Flex at `C:\flex`, invoked via the clean-client's `npm run tool -- build` wrapper.
- AIR SDK: Harman AIR SDK 51.3.1 (Windows).
- AIR compile-time library: `<AIR_HOME>\frameworks\libs\air\airglobal.swc` (passed as `-external-library-path+=` to amxmlc).
- AIR packager / runtime: `adt.bat` / `adl.exe` from the Harman SDK.
- Java: JDK 21.

Do **not** compile the full Habbo client tree directly with Harman `amxmlc.bat` — it hangs. `build.bat` deliberately uses the existing clean-client `npm run tool` command and only adds AIR compile support via `airglobal.swc`.

---

## Distribution note

The bundled `cert.p12` is **self-signed** and inherited from the `main` (NGHWin) branch — the certificate's internal CN still says "NGHWin" because regenerating it would invalidate the bundled signature. This doesn't affect runtime; the cert's display name is only visible in Windows' signature-properties dialog. Replace with a real signing certificate (and re-package) before distributing outside local testing. To generate a fresh self-signed cert:

```bat
build.bat cert
```
