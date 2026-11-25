const defaultUiLanguage = 'zh';

/// Only advertise locales with a packaged UI translation.
String normalizeUiLanguage(Object? value) =>
    value == 'en' ? 'en' : defaultUiLanguage;
