part of 'filesystem_web.dart';

@JS()
@anonymous
extension type JSObjectType._(JSObject _) implements JSObject {
  JSObjectType() : this._ = JSObject();
}

extension WindowExtension on web.Window {
  external LaunchQueue get launchQueue;
  external JSPromise showSaveFilePicker([SaveFilePickerOptions options]);
}

typedef LaunchConsumer = JSFunction;

@JS('LaunchParams')
extension type LaunchParams._(JSObject _) implements JSObject {
  external String? get targetURL;
  external JSArray get files;
}

@JS('LaunchQueue')
extension type LaunchQueue._(JSObject _) implements JSObject {
  external JSVoid setConsumer(LaunchConsumer consumer);
}

typedef StartInDirectory = JSAny?;

@JS()
@anonymous
extension type FilePickerAcceptType._(JSObject _) implements JSObject {
  external factory FilePickerAcceptType({
    String description,
    JSAny? accept,
  });

  external set description(String value);
  external String get description;
  external set accept(JSAny? value);
  external JSAny? get accept;
}

@JS()
@anonymous
extension type FilePickerOptions._(JSObject _) implements JSObject {
  external factory FilePickerOptions({
    JSArray types,
    bool excludeAcceptAllOption,
    String id,
    StartInDirectory startIn,
  });

  external set types(JSArray value);
  external JSArray get types;
  external set excludeAcceptAllOption(bool value);
  external bool get excludeAcceptAllOption;
  external set id(String value);
  external String get id;
  external set startIn(StartInDirectory value);
  external StartInDirectory get startIn;
}

@JS()
@anonymous
extension type SaveFilePickerOptions._(JSObject _)
    implements FilePickerOptions {
  external factory SaveFilePickerOptions({String? suggestedName});

  external set suggestedName(String? value);
  external String? get suggestedName;
}
