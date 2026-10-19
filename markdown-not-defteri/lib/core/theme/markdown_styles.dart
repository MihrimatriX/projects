import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'app_theme.dart';

MarkdownStyleSheet markdownStyleSheet(BuildContext context, {bool dark = false}) {
  final fg = dark ? AppColors.foregroundDark : AppColors.foreground;
  final preview = dark ? AppColors.textSecondaryDark : AppColors.textPreview;
  final codeBg = dark ? AppColors.codeBgDark : AppColors.codeBg;

  return MarkdownStyleSheet(
    h1: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.02,
      color: fg,
    ),
    h2: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: -0.01,
      color: fg,
    ),
    h3: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: fg,
    ),
    p: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 17,
      height: 1.65,
      color: preview,
    ),
    listBullet: TextStyle(fontSize: 17, height: 1.65, color: preview),
    blockquote: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 17,
      fontStyle: FontStyle.italic,
      height: 1.65,
      color: dark ? AppColors.textSecondaryDark : AppColors.textSecondary,
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: dark ? AppColors.borderDark : AppColors.border,
          width: 3,
        ),
      ),
    ),
    code: TextStyle(
      fontFamily: 'Consolas',
      fontSize: 15,
      backgroundColor: codeBg,
      color: fg,
    ),
    codeblockDecoration: BoxDecoration(
      color: AppColors.codeBlockBg,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(16),
    a: const TextStyle(color: AppColors.primary),
  );
}
