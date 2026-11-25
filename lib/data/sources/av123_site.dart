import 'package:miru_alpha/utils/store/nsfw_session.dart';

final av123Home = Uri.https('123av.com', '/');

/// A visit cannot outlive the individual NSFW opt-in that created it.
final class Av123Visit {
  Av123Visit(this._access) : _epoch = _access.epoch, _issued = _access.enabled;

  final NsfwSession _access;
  final int _epoch;
  final bool _issued;

  bool get active => _issued && _access.enabled && _access.epoch == _epoch;

  bool allowNavigation(String address) {
    if (!active ||
        address.contains('\\') ||
        _controlOrSpace.hasMatch(address) ||
        !_officialAuthority.hasMatch(address)) {
      return false;
    }
    final uri = Uri.tryParse(address);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        !uri.authority.contains('@') &&
        uri.port == 443 &&
        const {'123av.com', 'www.123av.com'}.contains(uri.host);
  }

  static final _controlOrSpace = RegExp(r'[\x00-\x20\x7f]');
  // Check the raw authority before Uri normalizes away empty user-info.
  static final _officialAuthority = RegExp(
    r'^https://(?:www\.)?123av\.com(?::443)?(?:[/?#]|$)',
    caseSensitive: false,
  );
}
