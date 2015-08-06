#!/bin/sh

KEYCHAIN=ios-build.keychain

# Delete temporary keychain
security delete-keychain "$KEYCHAIN"
