## Releasing

This document contains a general description and tips for releasing Influxdb3-java using Github Actions with the ultimate goal of pushing the release to Maven Central.

### Generating a new GPG signing key

1. Generate a random password for the key.  

e.g. On a Linux box... 

```
$ head -c 6 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9+-'
HiF4YcF
```

Store this somewhere safe.

2. Generate a key with a passphrase and no expiration. 

```
gpg --batch --passphrase=<GENERATED_PASSWORD> --quick-generate-key "<your-username>@users.noreply.github.com" default default never
```

TODO - to be continued.

### Addenda 

#### Revoking a compromised GPG2 key

1. verify that the key is on the local server.

```
$ gpg2 --list-keys
/home/karl/.gnupg/pubring.kbx
-----------------------------
pub   ed25519 2026-07-27 [SC] [expires: 2029-07-26]
      KEY_ID_REDACTED
uid           [ultimate] karel-rehor@users.noreply.github.com
sub   REDACTED 2026-07-27 [E]

```

or...

```
$ gpg2 --list-keys KEY_ID_REDACTED
pub   ed25519 2026-07-27 [SC] [expires: 2029-07-26]
      KEY_ID_REDACTED
uid           [ultimate] karel-rehor@users.noreply.github.com
sub   REDACTED 2026-07-27 [E]
```

2. Verify that the key is on the remote server. 

```
$ gpg2 --keyserver keyserver.ubuntu.com --search-keys KEY_ID_REDACTED
gpg: data source: http://185.125.188.27:11371
(1)	karel-rehor@users.noreply.github.com
	  263 bit EDDSA key REDACTED, created: 2026-07-27
Keys 1-1 of 1 for "KEY_ID_REDACTED".  Enter number(s), N)ext, or Q)uit > 1
gpg: key REDACTED: "karel-rehor@users.noreply.github.com" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1
```

3. Create a revocation request locally. 

```
$ gpg2 --output revoke-karel-rehor.asc --gen-revoke KEY_ID_REDACTED
...
```

4. Revoke the key locally.

```
$ gpg2 --import revoke-karel-rehor.asc 
gpg: key REDACTED: "karel-rehor@users.noreply.github.com" revocation certificate imported
gpg: Total number processed: 1
gpg:    new key revocations: 1
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
gpg: next trustdb check due at 2029-07-26
```

5. Verify revocation succeeded. 

```
$ gpg2 --list-keys
/home/karl/.gnupg/pubring.kbx
-----------------------------
pub   ed25519 2026-07-27 [SC] [revoked: 2026-09-03]
      KEY_ID_REDACTED
uid           [ revoked] karel-rehor@users.noreply.github.com
```

6. Push change of key state to remote server. 

```
$ gpg2 --keyserver keyserver.ubuntu.com --send-keys KEY_ID_REDACTED
gpg: sending key REDACTED to hkp://keyserver.ubuntu.com
```

7. Verify key state on remote server.

```
$ gpg2 --keyserver keyserver.ubuntu.com --search-keys KEY_ID_REDACTED
gpg: data source: http://185.125.188.27:11371
gpg: key "KEY_ID_REDACTED" not found on keyserver
```

8. Delete secret key locally. 

```
$ gpg2 --delete-secret-key KEY_ID_REDACTED
...
# Confirmation required
```

9. Delete key locally

```
$ gpg2 --delete-key 01EAECEC736391172C6520F48B5778484117B952
...
# Confirmation required
```

10. Verify key is deleted

```
$ gpg2 --list-keys
gpg: checking the trustdb
gpg: no ultimately trusted keys found
```
