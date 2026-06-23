import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared secure storage for credentials (e.g. Xtream login).
///
/// On macOS we use the legacy keychain (`usesDataProtectionKeychain: false`)
/// so the app works under ad-hoc/local signing. The data-protection keychain
/// (the default) requires a signed `keychain-access-groups` entitlement, which
/// needs a paid Apple Developer team and breaks local debug runs with error
/// -34018 ("a required entitlement isn't present").
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
