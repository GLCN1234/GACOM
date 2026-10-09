/// Parses [raw] and returns it only when it is a plain https URL with a host.
/// Use before launching or following any URL that came from the server, a
/// user, or a model (blocks javascript:, intent:, file:, http:, data: etc.).
Uri? safeHttpsUri(String? raw) {
  if (raw == null) return null;
  final String s = raw.trim();
  if (s.isEmpty || s.length > 2000) return null;
  final Uri? u = Uri.tryParse(s);
  if (u == null) return null;
  if (u.scheme.toLowerCase() != 'https') return null;
  if (u.host.isEmpty || u.userInfo.isNotEmpty) return null;
  return u;
}
