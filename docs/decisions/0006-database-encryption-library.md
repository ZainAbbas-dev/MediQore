# 0006. Library for the encrypted local database

- **Status:** Accepted for the library: the updated scope's Tools table names "SQLite3MultipleCiphers via Drift NativeDatabase (sqlite3 package)". Superseded for the key: see the update below
- **Date:** 2026-10-04
- **Scope:** M3 FE-2 ("encrypted SQLite (Drift + sqflite_sqlcipher) with AES-256"), LI-8; Tools table: sqflite_sqlcipher
- **Roadmap:** Module 3, "AES-256 encrypted local storage with Drift + sqflite_sqlcipher"; Module 1, "derive the SQLCipher key from the password … a correct password unlocks the local database"

> **Update, 2026-10-10 (updated final scope and roadmap of 10 Oct 2026).** The updated scope (M3 FE-2, LI-8, Tools table) adopts this record's library choice: Drift's native database with SQLite3MultipleCiphers and its SQLCipher-compatible AES-256 cipher. The key changes: it is now a **random 256-bit key generated on the phone, stored wrapped by a non-exportable Android Keystore key** (flutter_secure_storage) and unwrapped in memory when the database opens, **never derived from the password or PIN**. The password-derived key described below is replaced in the Phase 1 revision; a password reset then no longer deletes and re-downloads the local data.

## Context

The app keeps its records in Drift. Drift reaches SQLite through `package:sqlite3`, the package Drift itself is built on.

`sqflite_sqlcipher` is a different SQLite plugin: it runs its own copy of SQLCipher behind a platform channel, with the `sqflite` API. Drift's database class cannot run on it:

- the official Drift backends use `package:sqlite3` or `sqflite`, not `sqflite_sqlcipher`;
- the community wrappers that joined the two are unmaintained.

Since version 3, `package:sqlite3` can bundle an encrypting SQLite instead of the plain one, chosen by one setting in `pubspec.yaml` ([hook options](https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md)). It offers two encrypting builds:

| | SQLCipher | SQLite3 Multiple Ciphers |
|---|---|---|
| Encryption | AES-256, SQLCipher format | Several ciphers, including AES-256 in the SQLCipher format |
| Extra system libraries | OpenSSL on Windows, Linux and Android | None |
| `flutter test` on the team's Windows laptops | Needs OpenSSL DLLs installed | Works as is |

## Decision

**Use the SQLite3 Multiple Ciphers build of `package:sqlite3`, set to AES-256 in the SQLCipher format.**

- No new Dart package: `package:sqlite3` was already in the app through Drift. `pubspec.yaml` now lists it, and `path_provider`, which was also in the app already, as direct dependencies, because the opener imports them.
- The cipher is `sqlcipher` with `legacy = 4`: AES-256-CBC with HMAC-SHA512 per page, the format SQLCipher 4 writes.
- The key is the 32-byte key derived from the password with PBKDF2-HMAC-SHA256 (120,000 iterations, M1 FE-2). It is passed raw, so SQLCipher does not run a second key derivation on every open.
- The database is opened at sign-in and closed when the app locks (`mobile/lib/data/database_opener.dart`, `Session`).
- **Older phones:** a phone that ran an earlier version has an unencrypted database. It is encrypted in place with the key at the next sign-in, keeping records that are not yet synced.
- **New password (LI-8):** a new password gives a new key. The old database cannot be read any more, so it is deleted and filled again from the server. If it held unsynced records, the home screen says they are lost. This is why the portal asks to sync before a password reset.
- **Before sign-in** the database cannot be opened. The number of records waiting to sync is therefore kept, as a number only, in the phone's settings, for the rule that another LHW cannot sign in over unsynced records.

## Evidence

`mobile/test/data/encrypted_database_test.dart` uses the real file, not a mock:

- the file shows neither the records nor the SQLite header;
- a wrong key is refused;
- an unencrypted database is encrypted in place with its records kept;
- deleting the database leaves an empty one at the next open.

## Consequences

- The Tools table should read "SQLite3 Multiple Ciphers (through package:sqlite3, SQLCipher-format AES-256)" instead of "sqflite_sqlcipher". The Word scope document, `roadmap.pdf` and the Markdown copies need the same change once the supervisor agrees.
- `package:sqlite3` downloads the SQLite3 Multiple Ciphers binaries from its GitHub releases at build time, as it did for plain SQLite. The downloads are checked against hashes published with the package.
- SQLite3 Multiple Ciphers has its own licence (MIT); it is compatible with the project.

## Sign-off

| Name | Role | Decision | Date |
|---|---|---|---|
| Muhammad Zain Abbas | Team (mobile) | Go-ahead to build | 2026-10-04 |
| Zain Ali | Team | | |
| Ma'am Sajida Kalsoom | Supervisor (Tools table change) | | |
