import 'package:flutter/material.dart';

import '../../../core/task_input_parser.dart';
import '../../../core/theme/app_colors.dart';

class QuickAddBar extends StatefulWidget {
  const QuickAddBar({
    super.key,
    required this.onSubmit,
    this.hint = '+ Görev ekle veya #etiket @bağlam',
    this.focusNode,
  });

  final Future<void> Function(String title) onSubmit;
  final String hint;
  final FocusNode? focusNode;

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _ownsFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
    if (widget.focusNode != null) {
      _focus = widget.focusNode!;
    } else {
      _focus = FocusNode();
      _ownsFocus = true;
    }
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    _focus.removeListener(_onFocusChange);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  ParsedTaskInput get _parsed => parseTaskInput(_controller.text);

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    await widget.onSubmit(text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final parsed = _parsed;
    final chips = [
      ...parsed.hashTags.map((t) => '#$t'),
      ...parsed.contexts.map((c) => '@$c'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardFor(brightness),
        border: Border.all(color: AppColors.borderFor(brightness)),
        borderRadius: BorderRadius.circular(AppLayout.radius),
        boxShadow: AppColors.cardShadow(brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _focus.hasFocus ? AppColors.accent : Colors.transparent,
                  width: _focus.hasFocus ? 1 : 0,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(color: AppColors.secondaryTextFor(brightness)),
                      ),
                      style: TextStyle(fontSize: 15, color: AppColors.primaryTextFor(brightness)),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ekle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map(
                      (c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoftFor(brightness),
                          borderRadius: BorderRadius.circular(AppLayout.radiusChip),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: brightness == Brightness.dark ? const Color(0xFFBFDBFE) : AppColors.accentHover,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
