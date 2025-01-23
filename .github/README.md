This is a test fork of the [Python-based EUDIW
issuer](https://github.com/eu-digital-identity-wallet/eudi-srv-web-issuing-eudiw-py/),
aiming to ease local test deployments.

## Requirements

This setup assumes two devices (one Android, one Linux), connected to
the same local network. The Android should also be connected to the
Linux device and appropriate tooling should be installed (Android
Studio IDE, Android SDK, Android Debugging Bridge).

## Set up

### This repo (issuer)

0. Clone the repo with iniitalized and updated git submodules:

```bash
$ git clone --recurse-submodules <url>
```

If you have already cloned the project without `--recurse-submodules`, do:

```bash
git submodule update --init
```

1. Switch to branch "local-deploy".

2. Find the <IP> of the Linux device in the local network (`ifconfig ...`).

3. In this repo, search and replace: `192.168.134.214` -> `<IP>`:
```
./patch_ip.sh IP
```
(To revert the IP patch above, run: `./undo_patch_ip.sh`)

4. Run `./setup.sh` (it will need `sudo` access).

5. Run the issuer: `./run-issuer.sh`

### Android wallet

1. Clone [the Android app fork](https://github.com/gfour/eudi-app-android-wallet-ui)
   and switch to branch "local-deploy".

2. Run `./setup.sh`. This assumes that the issuer repository is also
   cloned, see variable `ISSUER_DIR` in the script.

3. Patch the issuer IP as above:

4. Build the Android app (`./gradlew assembleDevDebug` or through Android Studio) and deploy
   it to the connected Android device (`adb install path/to/app.apk`).

## Use

1. Linux device: choose a credential type to issue (`https://<IP>:5000/credential_offer_choice`)
   and continue to generate a QR code for a credential.

2. Scan the QR code with the Android app. When prompted, use the Form Country (FC).

## Run with EBSI agent

### [`ebsi-agent`](https://github.com/fmerg/ebsi-agent) updates

The submodule tracks the `develop` upstream.

```bash
$ ./ebsi-agent.sh info      # Check for upstream changes
$ ./ebsi-agent.sh update    # Pull changes from upstream
$ ./ensi-agent.sh commit    # Commit the fact that the downstream has been updated
```

For more options:

```bash
$ ./ebsi-agent.sh --help
```

### Run service with docker

```bash
$ docker compose up
```
