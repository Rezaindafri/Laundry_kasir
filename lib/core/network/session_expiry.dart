/// Carries only the token used by the rejected request. Never log/persist it.
/// Comparing it with the current token prevents a late response from an old
/// session from signing out an account that has just logged in.
class SessionExpiryEvent {
  final String accessToken;
  final int statusCode;

  const SessionExpiryEvent({
    required this.accessToken,
    required this.statusCode,
  });
}
