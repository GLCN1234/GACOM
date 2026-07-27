// Platform-safe localStorage wrapper for edu mode persistence.
// On web: reads/writes window.localStorage so the preference survives
// page refreshes and browser closes. On mobile: falls back to a no-op
// (mobile apps don't reload from scratch on reopen like web does).

import 'edu_prefs_stub.dart'
    if (dart.library.html) 'edu_prefs_web.dart' as _impl;

bool getEduMode() => _impl.getEduMode();
void setEduMode(bool v) => _impl.setEduMode(v);
