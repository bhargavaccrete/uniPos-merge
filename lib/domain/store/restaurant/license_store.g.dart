// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'license_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LicenseStore on _LicenseStore, Store {
  Computed<LicenseStatus>? _$statusComputed;

  @override
  LicenseStatus get status =>
      (_$statusComputed ??= Computed<LicenseStatus>(() => super.status,
              name: '_LicenseStore.status'))
          .value;
  Computed<bool>? _$isLicensedComputed;

  @override
  bool get isLicensed =>
      (_$isLicensedComputed ??= Computed<bool>(() => super.isLicensed,
              name: '_LicenseStore.isLicensed'))
          .value;
  Computed<bool>? _$isExpiringSoonComputed;

  @override
  bool get isExpiringSoon =>
      (_$isExpiringSoonComputed ??= Computed<bool>(() => super.isExpiringSoon,
              name: '_LicenseStore.isExpiringSoon'))
          .value;
  Computed<DeviceInfo?>? _$deviceInfoComputed;

  @override
  DeviceInfo? get deviceInfo =>
      (_$deviceInfoComputed ??= Computed<DeviceInfo?>(() => super.deviceInfo,
              name: '_LicenseStore.deviceInfo'))
          .value;

  late final _$licenseInfoAtom =
      Atom(name: '_LicenseStore.licenseInfo', context: context);

  @override
  LicenseInfo? get licenseInfo {
    _$licenseInfoAtom.reportRead();
    return super.licenseInfo;
  }

  @override
  set licenseInfo(LicenseInfo? value) {
    _$licenseInfoAtom.reportWrite(value, super.licenseInfo, () {
      super.licenseInfo = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_LicenseStore.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_LicenseStore.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$loadCachedLicenseAsyncAction =
      AsyncAction('_LicenseStore.loadCachedLicense', context: context);

  @override
  Future<void> loadCachedLicense() {
    return _$loadCachedLicenseAsyncAction.run(() => super.loadCachedLicense());
  }

  late final _$activateLicenseAsyncAction =
      AsyncAction('_LicenseStore.activateLicense', context: context);

  @override
  Future<bool> activateLicense(String key,
      {String businessName = '', int businessCategory = 6}) {
    return _$activateLicenseAsyncAction.run(() => super.activateLicense(key,
        businessName: businessName, businessCategory: businessCategory));
  }

  late final _$refreshLicenseAsyncAction =
      AsyncAction('_LicenseStore.refreshLicense', context: context);

  @override
  Future<void> refreshLicense() {
    return _$refreshLicenseAsyncAction.run(() => super.refreshLicense());
  }

  late final _$validateKeyAsyncAction =
      AsyncAction('_LicenseStore.validateKey', context: context);

  @override
  Future<bool> validateKey(String key) {
    return _$validateKeyAsyncAction.run(() => super.validateKey(key));
  }

  late final _$checkStatusAsyncAction =
      AsyncAction('_LicenseStore.checkStatus', context: context);

  @override
  Future<void> checkStatus() {
    return _$checkStatusAsyncAction.run(() => super.checkStatus());
  }

  late final _$heartbeatAsyncAction =
      AsyncAction('_LicenseStore.heartbeat', context: context);

  @override
  Future<void> heartbeat() {
    return _$heartbeatAsyncAction.run(() => super.heartbeat());
  }

  late final _$injectMockLicenseAsyncAction =
      AsyncAction('_LicenseStore.injectMockLicense', context: context);

  @override
  Future<void> injectMockLicense({int validityDays = 30}) {
    return _$injectMockLicenseAsyncAction
        .run(() => super.injectMockLicense(validityDays: validityDays));
  }

  late final _$injectExpiredLicenseAsyncAction =
      AsyncAction('_LicenseStore.injectExpiredLicense', context: context);

  @override
  Future<void> injectExpiredLicense() {
    return _$injectExpiredLicenseAsyncAction
        .run(() => super.injectExpiredLicense());
  }

  late final _$deactivateLicenseAsyncAction =
      AsyncAction('_LicenseStore.deactivateLicense', context: context);

  @override
  Future<void> deactivateLicense() {
    return _$deactivateLicenseAsyncAction.run(() => super.deactivateLicense());
  }

  @override
  String toString() {
    return '''
licenseInfo: ${licenseInfo},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
status: ${status},
isLicensed: ${isLicensed},
isExpiringSoon: ${isExpiringSoon},
deviceInfo: ${deviceInfo}
    ''';
  }
}
