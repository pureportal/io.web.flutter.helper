import 'package:fluttertoast/fluttertoast.dart';

toast({required String message, String color = "#0074D9"}) {
  Fluttertoast.showToast(
    msg: message,
    timeInSecForIosWeb: 3,
    webBgColor: color,
    webPosition: "center",
    gravity: ToastGravity.BOTTOM,
  );
}

toastError({required String message}) {
  toast(message: message, color: "#85144b");
}

toastWarn({required String message}) {
  toast(message: message, color: "#FF851B");
}

toastSuccess({required String message}) {
  toast(message: message, color: "#2ECC40");
}
