import 'dart:html' as html;

const _key = 'gacom_edu_mode';

bool getEduMode() {
  try {
    return html.window.localStorage[_key] == 'true';
  } catch (_) {
    return false;
  }
}

void setEduMode(bool v) {
  try {
    if (v) {
      html.window.localStorage[_key] = 'true';
    } else {
      html.window.localStorage.remove(_key);
    }
  } catch (_) {}
}
