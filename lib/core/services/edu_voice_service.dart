// Platform router — picks the real web implementation on web,
// and a safe no-op stub everywhere else.
export 'edu_voice_stub.dart'
    if (dart.library.html) 'edu_voice_web.dart';
