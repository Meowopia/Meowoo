import 'package:material_ui/material_ui.dart';
import 'package:miru_alpha/data/sources/kazumi_rule_import.dart';
import 'package:miru_alpha/utils/core/i18n.dart';

Future<void> showKazumiRulePreview(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _KazumiRulePreview(),
);

class _KazumiRulePreview extends StatefulWidget {
  const _KazumiRulePreview();

  @override
  State<_KazumiRulePreview> createState() => _KazumiRulePreviewState();
}

class _KazumiRulePreviewState extends State<_KazumiRulePreview> {
  final _text = TextEditingController();
  List<KazumiRuleReview> _reviews = const [];
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _inspect() {
    try {
      final reviews = inspectKazumiRules(_text.text);
      setState(() {
        _reviews = reviews;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _reviews = const [];
        _error = 'kazumi_import.${error.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 560,
      height: (MediaQuery.sizeOf(context).height * .8).clamp(0, 700),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'kazumi_import.title'.i18n,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  Text('kazumi_import.notice'.i18n),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('kazumi-rule-input'),
                    controller: _text,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 256 * 1024,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'kazumi_import.input'.i18n,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {
                      _reviews = const [];
                      _error = null;
                    }),
                  ),
                  if (_error case final error?)
                    Semantics(liveRegion: true, child: Text(error.i18n)),
                  for (final review in _reviews)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${review.index} ${review.name}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (review.origin case final origin?) Text(origin),
                            Text(
                              (review.valid
                                      ? 'kazumi_import.schema_ok'
                                      : 'kazumi_import.schema_invalid')
                                  .i18n,
                            ),
                            for (final issue in review.issues) Text(issue),
                            if (review.requirements.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('kazumi_import.requires'.i18n),
                              for (final requirement in review.requirements)
                                Text('kazumi_import.req_$requirement'.i18n),
                            ],
                            const SizedBox(height: 8),
                            Text('kazumi_import.not_installed'.i18n),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('kazumi_import.close'.i18n),
                ),
                FilledButton(
                  key: const ValueKey('kazumi-rule-check'),
                  onPressed: _inspect,
                  child: Text('kazumi_import.check'.i18n),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
