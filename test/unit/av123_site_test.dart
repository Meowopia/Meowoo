import 'package:flutter_test/flutter_test.dart';
import 'package:miru_alpha/data/sources/av123_site.dart';
import 'package:miru_alpha/utils/store/nsfw_session.dart';

void main() {
  test('an off-state visit stays invalid even after opt-in', () {
    final access = NsfwSession();
    final visit = Av123Visit(access);
    expect(visit.allowNavigation(av123Home.toString()), isFalse);
    access.setEnabled(true);
    expect(visit.allowNavigation(av123Home.toString()), isFalse);
  });

  test('ordinary official HTTPS pages and language redirects are allowed', () {
    final visit = Av123Visit(NsfwSession()..setEnabled(true));
    for (final url in [
      av123Home.toString(),
      'https://123av.com/en',
      'https://www.123av.com/ja',
      'https://123av.com:443/en?q=fixture%20test',
    ]) {
      expect(visit.allowNavigation(url), isTrue, reason: url);
    }
  });

  test('off-domain, ambiguous and non-HTTPS navigations are denied', () {
    final visit = Av123Visit(NsfwSession()..setEnabled(true));
    for (final url in [
      'https://not-123av.com/',
      'https://123av.com.example.test/',
      'https://x.123av.com/',
      'https://123av.com@elsewhere.test/',
      'https://elsewhere.test@123av.com/',
      'https://@123av.com/',
      'https://123av.com:444/',
      'http://123av.com/',
      '//123av.com/',
      ' https://123av.com/',
      r'https://123av.com\@elsewhere.test/',
      'https://127.0.0.1/',
      'about:blank',
      'javascript:alert(1)',
      'intent://123av.com/',
    ]) {
      expect(visit.allowNavigation(url), isFalse, reason: url);
    }
  });

  test('revocation invalidates a pending navigation after re-enable', () {
    final access = NsfwSession()..setEnabled(true);
    final visit = Av123Visit(access);
    expect(visit.allowNavigation(av123Home.toString()), isTrue);
    access.setEnabled(false);
    access.setEnabled(true);
    expect(visit.active, isFalse);
    expect(visit.allowNavigation(av123Home.toString()), isFalse);
    expect(Av123Visit(access).allowNavigation(av123Home.toString()), isTrue);
  });
}
