fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android validate_auth

```sh
[bundle exec] fastlane android validate_auth
```

Check the service-account key and Play API access

### android track_info

```sh
[bundle exec] fastlane android track_info
```

Read current version codes on internal and alpha tracks

### android upload_internal

```sh
[bundle exec] fastlane android upload_internal
```

Upload the signed AAB to internal testing

### android upload_alpha

```sh
[bundle exec] fastlane android upload_alpha
```

Upload the signed AAB to closed testing (alpha)

### android promote_alpha

```sh
[bundle exec] fastlane android promote_alpha
```

Promote the active internal-testing release to closed testing (alpha)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
