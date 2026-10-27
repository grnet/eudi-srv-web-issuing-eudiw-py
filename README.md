# EUDIW Issuer

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

**Important!** Before you proceed, please read
the [EUDI Wallet Reference Implementation project description](https://github.com/eu-digital-identity-wallet/.github/blob/main/profile/reference-implementation.md)


### Overview

The EUDIW Issuer is an implementation of  the PID and (Q)EAA Provider service.

The service provides, by default, support for `mso_mdoc` and `SD-JWT-VC`formats, for various credentials.

For authenticating the user, it requires the use of eIDAS node, OAUTH2 server or a simple form (for testing purposes).


### OpenId4VCI coverage

This version of the EUDIW Issuer has support for the [OpenId for Verifiable Credential Issuance (Version 1.0)](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html) protocol with the following coverage:


| Feature                                                   | Coverage                                                        |
|-------------------------------------------------------------------|-----------------------------------------------------------------|
| [Authorization Code flow](https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py/blob/main/api_docs/authorization.md)        | ✅ Support for scoped                                           |
| [Pre-authorized code flow](https://github.com/eu-digital-identity-wallet/eudi-srv-web-issuing-frontend-eudiw-py/blob/main/api_docs/pre-authorized.md)            | ✅                                                              |
| [Credential Offer](https://github.com/eu-digital-identity-wallet/eudi-srv-web-issuing-frontend-eudiw-py/blob/main/api_docs/credential_offer.md)                  | ✅ `authorization_code` , ✅ `pre-authorized_code`              |
| Dynamic Credential Request                                        | ✅                                                              |
| mso_mdoc format                                                   | ✅                                                              |
| SD-JWT-VC format                                                  | ✅                                                              |
| W3C VC DM                                                         | ❌                                                              |
| [Token Endpoint](https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py/blob/main/api_docs/token.md)                               | ✅                                                              |
| [Credential Endpoint](api_docs/credential.md)                     | ✅                                                              |
| Credential Issuer MetaData                                        | ✅ Unsigned metadata                                            | 
| [Nonce endpoint](api_docs/nonce_endpoint.md)                      | ✅                                                              | 
| [Deferred Endpoint](api_docs/deferred.md)                         | ✅ Encryption support                                           |
| Proof                                                             | ✅ JWT, Key Attestations                                        |
| Credential response encryption                                    | ✅                                                              |
| Credential request encryption                                     | ✅                                                              |
| [Notification Endpoint](api_docs/notification.md)                 | ✅                                                              |
| Pushed authorization request                                      | ✅                                                              |
| Wallet authentication                                             | ✅ public client, Wallet client attestations                    |
| Demonstrating Proof of Possession (DPoP)                          | ✅                                                              |
| PKCE                                                              | ✅                                                              |

You can use the EUDIW Issuer at [https://issuer.eudiw.dev/](https://issuer.eudiw.dev/), or install it locally.


### TS12: SCA attestations and transaction data

TS12 is the "Specification of Strong Customer Authentication (SCA) Implementation with the Wallet" (v1.0.1,
[eudi-doc-standards-and-technical-specifications](https://github.com/eu-digital-identity-wallet/eudi-doc-standards-and-technical-specifications)).
WE BUILD profiles it in [CS-12](https://github.com/webuild-consortium/wp4-architecture/blob/main/conformance-specs/cs-12-sca-payments.md).

#### What this issuer publishes

SCA-IBAN (SD-JWT VC) and SCA-Card (DPC) publish TS12 metadata in their SD-JWT VC type metadata
(`/credentials/sca/iban/1.0`, `/credentials/sca/card-dpc/1.0`):

- `category: urn:eu:europa:ec:eudi:sua:sca` (TS12 section 3), so that wallets process them as SCA attestations.
- `transaction_data_types` with `urn:eudi:sca:payment:1` (TS12 section 4.1, CS-12 section 7.2 item 5), from
  `app/metadata_config/transaction_data_types/sca_payment_1.json`: the schema by `schema_uri`, claim labels in
  `en` and `el` with a `visualisation` level, and the UI labels.

Each SCA type lists its transaction types in `issuer_config.type_metadata`. The OID4VCI issuer metadata and the
issued credentials do not carry TS12 metadata.

Not yet: `urn:eudi:sca:login_risk_transaction:1`, an SD-JWT SCA-User (TS12 covers SD-JWT only), and
`vct#integrity` / `extends#integrity` (the WE BUILD base VCTs still return 404).

#### TS12 gaps in the GRNET wallet and verifier

For this metadata to have an effect, wallets and verifiers have to use it. Read from the code of the `grnet`
branches, not tried on a device. Links point at the commits read.

**Wallet**

[`grnet/eudi-app-android-wallet-ui`](https://github.com/grnet/eudi-app-android-wallet-ui) and
[`grnet/eudi-lib-android-wallet-core`](https://github.com/grnet/eudi-lib-android-wallet-core). The wallet handles
`urn:eudi:sca:payment:1` for the WE BUILD PA2 demo (wallet PRs #4 and #5): it reads the payee, amount and currency,
shows a payment confirmation, and adds a random `jti` and an `amr` to the KB-JWT. Compared with TS12 and CS-12:

| # | Gap | TS12 / CS-12 | Where |
|---|---|---|---|
| W1 | Payments are enabled only in the `dev` flavor. The `demo` flavor registers only the QES types, so it does not accept a payment. | TS12 4.3 | [dev `WalletCoreConfigImpl.kt:125`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/dev/java/eu/europa/ec/corelogic/config/WalletCoreConfigImpl.kt#L125), cf. [demo `:83`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/demo/java/eu/europa/ec/corelogic/config/WalletCoreConfigImpl.kt#L83) |
| W2 | The type metadata is not read: no check of `category`, of `transaction_data_types` (whether the credential allows the type), or of `schema_uri`. wallet-core uses `TypeMetadataPolicy.NotUsed`. | TS12 3, 3.2 steps 1-3; CS-12 7.3 items 1, 4 | nothing in the app or wallet-core reads it |
| W3 | Labels come from the app, in English only (`strings.xml`), not from the metadata's claim `display`, `visualisation` and `ui_labels`. TS12 says the wallet SHALL use the attestation's labels, and SHALL stop if they are not available. | TS12 3.3.1-3.3.3; CS-12 7.3 items 5, 6 | [`strings.xml`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/resources-logic/src/main/res/values/strings.xml#L247-L257) |
| W4 | Only payee, amount and currency are read; other members (`pisp`, `execution_date`, `recurrence`, `amount_estimated`...) are ignored, so they are not shown. TS12's visualisation levels 1-3 require showing them. | TS12 3.3.1 | [`ScaPayment.kt:39`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/main/java/eu/europa/ec/corelogic/transactiondata/ScaPayment.kt#L39) (`ignoreUnknownKeys`) |
| W5 | The payload is not validated against the TS12 schema: `transaction_id` and `payee.id` (both REQUIRED) are optional here, and unknown members are accepted although the schema has `additionalProperties: false`. | TS12 3.2 step 4; CS-12 7.3 item 4 | [`ScaPayment.kt:72`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/main/java/eu/europa/ec/corelogic/transactiondata/ScaPayment.kt#L72), [`:96`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/main/java/eu/europa/ec/corelogic/transactiondata/ScaPayment.kt#L96), [`:39`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/main/java/eu/europa/ec/corelogic/transactiondata/ScaPayment.kt#L39) |
| W6 | The `amr` methods are not TS12's: `device_bound_key`, `biometric_device`, `screen_lock_device`. TS12 defines the values (e.g. `key_in_local_native_wscd`, `fingerprint_device` / `face_device`, `pin_6_or_more_digits`, `other`). | TS12 3.6 | [`ScaKeyAuthentication.kt:69-75`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/main/java/eu/europa/ec/corelogic/transactiondata/ScaKeyAuthentication.kt#L69-L75) |
| W7 | No `amr` at all when the system does not report how the user authenticated; TS12 makes `amr` REQUIRED, with at least two categories. | TS12 3.6; CS-12 7.3 item 8 | [`ScaKeyAuthentication.kt:52`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/main/java/eu/europa/ec/corelogic/transactiondata/ScaKeyAuthentication.kt#L52) |
| W8 | No `response_mode` claim in the KB-JWT (wallet PR #5: the hook does not see the request). | TS12 3.6 (REQUIRED); CS-12 7.3 item 8 | [`ScaPayment.kt:135`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/main/java/eu/europa/ec/corelogic/transactiondata/ScaPayment.kt#L135) adds only `jti` and `amr` |
| W9 | Only `payment:1`; no `login_risk_transaction:1`. Fine for now: this issuer publishes only `payment:1` too. | CS-12 7.1 | |
| W10 | Only SCA-Card (DPC) keys require the user (`userAuthenticatedKeyTypes`). An SCA-IBAN key does not, so a payment with SCA-IBAN, which this issuer declares for `payment:1`, never gets an `amr`. Fix: add `https://demo.eudiw.grnet.gr/issuer/credentials/sca/iban/1.0` and the WE BUILD base `https://webuildconsortium.eu/sca/sca-iban/1.0`. | TS12 3.6; CS-12 7.3 item 8 | [dev `WalletCoreConfigImpl.kt:241-245`](https://github.com/grnet/eudi-app-android-wallet-ui/blob/98d98b9e8b39646d19bf569c8c3dc7fe1b6e50e8/core-logic/src/dev/java/eu/europa/ec/corelogic/config/WalletCoreConfigImpl.kt#L241-L245) |

Checked on 2026-10-27 against the wallet's merged PRs #4 to #7: W1-W9 hold, and W10 comes from #5 together with this
issuer's SCA-IBAN metadata. #6 and #7 change nothing for TS12.

**Verifier**

[`grnet/eudi-srv-verifier-endpoint`](https://github.com/grnet/eudi-srv-verifier-endpoint) accepts any
`transaction_data` in a request: it checks `type` and `credential_ids`, decodes only the QES types strictly, and
checks the KB-JWT's `transaction_data_hashes`. The `amr` and `jti` checks that wallet PR #5 reports were made by the
WE BUILD PA2 demo merchant, not by this verifier.

| # | Gap | TS12 / CS-12 | Where |
|---|---|---|---|
| V1 | A payment payload is passed on as it is, without a check against the TS12 schema, so the verifier can send what wallets will reject. | TS12 3.2 | [`InitTransaction.kt:703-707`](https://github.com/grnet/eudi-srv-verifier-endpoint/blob/14fad270fea21d95292b8d337b69fe4494870b75/src/main/kotlin/eu/europa/ec/eudi/verifier/endpoint/port/input/InitTransaction.kt#L703-L707) |
| V2 | The KB-JWT's `jti`, `amr` (two categories) and `response_mode` are not checked, and `jti` is not returned as the authentication code. | CS-12 7.4 items 4, 5 | [`ValidateSdJwtVcOrMsoMdocVerifiablePresentation.kt:263`](https://github.com/grnet/eudi-srv-verifier-endpoint/blob/14fad270fea21d95292b8d337b69fe4494870b75/src/main/kotlin/eu/europa/ec/eudi/verifier/endpoint/adapter/out/presentation/ValidateSdJwtVcOrMsoMdocVerifiablePresentation.kt#L263) checks only `transaction_data_hashes` |
| V3 | The web UI ([`grnet/eudi-web-verifier`](https://github.com/grnet/eudi-web-verifier)) has no input for `transaction_data`. | | |


## :heavy_exclamation_mark: Disclaimer

The released software is a initial development release version:

-   The initial development release is an early endeavor reflecting the efforts of a short timeboxed
    period, and by no means can be considered as the final product.
-   The initial development release may be changed substantially over time, might introduce new
    features but also may change or remove existing ones, potentially breaking compatibility with your
    existing code.
-   The initial development release is limited in functional scope.
-   The initial development release may contain errors or design flaws and other problems that could
    cause system or other failures and data loss.
-   The initial development release has reduced security, privacy, availability, and reliability
    standards relative to future releases. This could make the software slower, less reliable, or more
    vulnerable to attacks than mature software.
-   The initial development release is not yet comprehensively documented.
-   Users of the software must perform sufficient engineering and additional testing in order to
    properly evaluate their application and determine whether any of the open-sourced components is
    suitable for use in that application.
-   We strongly recommend not putting this version of the software into production use.
-   Only the latest version of the software will be supported


## 1. Installation

Pre-requisites:

+ Python v. 3.9 or 3.10
+ Flask v. 2.3 or higher
+ PostgreSQL v. 16.14

Click [here](install.md) for detailed installation instructions.

## 2. Run

Click [here](install.md) for detailed instructions.

## 3. Frequently Asked Questions

### A. How to make your local EUDIW Issuer available on the Internet?

Please see detailed instructions in [install.md](install.md#4-make-your-local-eudiw-issuer-available-on-the-internet-optional).

### B. How to add a new credential to the issuer ?

Please see detailed instructions in [api_docs/add_credential.md](api_docs/add_credential.md).

### C. Can I use my IACA certificate with the EUDIW Issuer?

Yes. You must copy your IACA trusted certificate(s) (in PEM format) to the `trusted_CAs_path` folder. If you don't have an IACA certificate, we provide an example test IACA certificate for the country Utopia (UT).

See more information in [api_docs/configuration.md](api_docs/configuration.md#1-service-configuration).

### D. Can I use my Document Signer private key and certificate with the EUDIW Issuer?

Yes. Please follow the instructions in [api_docs/configuration.md](api_docs/configuration.md#2-configuration-of-countries). If you don't have Document Signer private key and certificate, we provide  test private DS keys and certificates, for country Utopia (UT).

### E. How can I create a credential offer to issue a credential?

Please see detailed instructions in [api_docs/credential_offer.md](https://github.com/eu-digital-identity-wallet/eudi-srv-web-issuing-frontend-eudiw-py/blob/main/api_docs/credential_offer.md).

### F. Can I test the pre-authorized flow?

Yes. Please see how in [api_docs/pre-authorized.md](https://github.com/eu-digital-identity-wallet/eudi-srv-web-issuing-frontend-eudiw-py/blob/main/api_docs/pre-authorized.md).

### H. Can I run the issuer in a Docker container?

Yes. Please see how in [Install Docker](install.md#6-docker).

### I. Where can I find reference revocation service information.

Information and guides on the revocation service can be found in the following [repository](https://github.com/eu-digital-identity-wallet/eudi-srv-statuslist-py).

### J. Can an external service create a credential offer?
Yes, please see how in [Credential Offer Endpoint](api_docs/credential_offer_create.md)

## How to contribute

We welcome contributions to this project. To ensure that the process is smooth for everyone
involved, follow the guidelines found in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

### License details

Copyright (c) 2023 European Commission

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
