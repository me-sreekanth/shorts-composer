import 'dart:async';
import 'dart:io';

class CustomMediaStream extends Stream<List<int>> {
  final Stream<List<int>> _stream;
  final int _totalLength;
  final Function(double) _onUploadProgress;
  int _bytesUploaded = 0;

  CustomMediaStream(this._stream, this._totalLength, this._onUploadProgress);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      (data) {
        _bytesUploaded += data.length;
        _onUploadProgress(_bytesUploaded / _totalLength);
        if (onData != null) {
          onData(data);
        }
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
