This is a test fork of the [Python-based EUDIW
issuer](https://github.com/eu-digital-identity-wallet/eudi-srv-web-issuing-eudiw-py/),
aiming to ease local test deployments.

## Requirements

This setup assumes two devices (one Android, one Linux).

## Set up

### This repo (issuer)

1. Switch to branch "local-deploy-v3".

2. Run `./setup-issuer.sh` to setup the issuer (e.g., set up virtual
   environment, install dependencies, generate self-signed certificate
   bound to the local host IP).

3. Optional: consult the last section in the output of the command
   above to find how to set up local signing certificates (signed
   by a local IACA certificate).

4. Run `./run-issuer.sh` to spin up the issuer server.

### Android wallet

1. Clone [the Android app fork](https://github.com/gfour/eudi-app-android-wallet-ui)
   and switch to branch "local-deploy-v2".

3. Run the issuer as above

4. Build the Android app (`./gradlew assembleDevDebug` or through Android Studio) and deploy
   it to the connected Android device (`adb install path/to/app.apk`).

## Use

1. Linux device: choose a credential type to issue (`https://<IP>:5500/credential_offer_choice`)
   and continue to generate a QR code for a credential.

2. Scan the QR code with the Android app. When prompted, use the Form Country (FC).
