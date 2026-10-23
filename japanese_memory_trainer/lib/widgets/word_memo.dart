import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-10-23 단어 하나에 사용자가 직접 적은 연상 메모(소리·이미지·이야기)를 보여 주고,
/// 누르면 입력창을 열어 고쳐 쓰게 하는 한 줄 카드다. 메모가 비어 있으면 쓰기를 권하는 문구를 보여 준다.
class WordMemoTile extends StatefulWidget {
  const WordMemoTile({
    super.key,
    required this.store,
    required this.wordId,
    this.accent = Washi.shu,
  });

  final StudyStore store;
  final String wordId;
  final Color accent;

  @override
  State<WordMemoTile> createState() => _WordMemoTileState();
}

class _WordMemoTileState extends State<WordMemoTile> {
  /// 2026-10-23 입력창을 열고, 저장을 누르면 기기에 기록한 뒤 카드를 다시 그린다.
  Future<void> _edit() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _MemoDialog(initial: widget.store.memoOf(widget.wordId)),
    );
    if (result == null) return;
    try {
      await widget.store.setMemo(widget.wordId, result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모를 저장하지 못했습니다. 다시 시도해 주세요.')),
      );
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.store.memoOf(widget.wordId);
    final empty = memo.isEmpty;
    return InkWell(
      key: ValueKey('memo-${widget.wordId}'),
      borderRadius: BorderRadius.circular(12),
      onTap: _edit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                size: 20, color: widget.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                empty ? '나만의 연상 메모 쓰기 (소리·이미지·이야기로 연결)' : memo,
                style: TextStyle(
                  fontSize: 14,
                  color: empty ? Washi.inkSoft : Washi.ink,
                  fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 18, color: Washi.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// 2026-10-23 메모 입력창. 컨트롤러를 이 위젯이 직접 만들고 닫힐 때 정리한다.
class _MemoDialog extends StatefulWidget {
  const _MemoDialog({required this.initial});

  final String initial;

  @override
  State<_MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<_MemoDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('나만의 연상 메모'),
      content: TextField(
        key: const ValueKey('memo-field'),
        controller: _controller,
        autofocus: true,
        maxLength: StudyStore.memoMaxLength,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: '예: 비슷한 한국어 소리나 장면을 떠올려 이야기로 묶어 보세요',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('memo-save'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
