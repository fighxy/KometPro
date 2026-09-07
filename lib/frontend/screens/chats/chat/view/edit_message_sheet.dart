import 'package:flutter/material.dart';
import 'package:komet/core/config/app_fonts.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';

class EditMessageSheet extends StatefulWidget {
  final String text;
  final Iterable<FormatRange> formatRanges;
  final Widget Function(
    RichMessageController controller,
    BuildContext context,
    EditableTextState editableState,
  )
  contextMenuBuilder;

  const EditMessageSheet({
    required this.text,
    required this.formatRanges,
    required this.contextMenuBuilder,
  });

  @override
  State<EditMessageSheet> createState() => EditMessageSheetState();
}

class EditMessageSheetState extends State<EditMessageSheet> {
  late final RichMessageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RichMessageController(text: widget.text)
      ..setFormatRanges(widget.formatRanges);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Изменить сообщение',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: displayFontOf(context),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: cs.onSurface),
            contextMenuBuilder: (ctx, state) =>
                widget.contextMenuBuilder(_controller, ctx, state),
            decoration: InputDecoration(
              hintText: 'Текст сообщения',
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_controller.buildContent()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
