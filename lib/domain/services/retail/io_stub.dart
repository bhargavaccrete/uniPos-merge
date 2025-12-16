// Stub for dart:io types on web platform
// This file is used when compiling for web where dart:io is not available

class File {
  File(String path);

  Future<bool> exists() async => false;
  Future<void> delete() async {}
  Future<void> writeAsString(String contents) async {}
  Future<String> readAsString() async => '';
  Future<int> length() async => 0;
  DateTime lastModifiedSync() => DateTime.now();
  String get path => '';
}

class Directory {
  Directory(String path);

  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  List<dynamic> listSync() => [];
  String get path => '';
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
}