class Error {
  final String message;
  final int code;
  final Map<String, dynamic> data;

  Error(this.message, this.code, this.data);

  @override
  String toString() {
    return 'Error: $message, code: $code, data: $data';
  }
}
