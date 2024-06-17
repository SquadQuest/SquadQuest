import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void setWebHandler(String handlerName, Function handler) {
  globalContext.setProperty(
      handlerName.toJS,
      (JSObject data) {
        handler(data.dartify() as Map);
      }.toJS);
}
