import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/components/inputs/segmented_control.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

// ========== 复用数据（评论输入、消息界面共用）==========

/// 颜文字小类 key 列表
const List<String> kKaomojiSubKeys = [
  'happy', 'sad', 'angry', 'love', 'surprise', 'cute', 'cool',
];

const Map<String, String> kEmojiTabLabels = {
  'happy': '开心',
  'sad': '难过',
  'angry': '愤怒',
  'love': '爱心',
  'surprise': '惊讶',
  'cute': '可爱',
  'cool': '酷炫',
  'emoji': 'Emoji',
};

const Map<String, List<String>> kKaomojis = {
  'happy': [
    '(´∀｀)', '(￣▽￣)', '(´▽｀)', '(￣ω￣)', '(´ω｀)', '(￣∀￣)',
    '(๑´ㅂ`๑)', '(｡♥‿♥｡)', '(◕‿◕)', '(*´▽`*)', '(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧',
    '(＾◡＾)', '(◠‿◠)', '(´꒳`)', '(◡ ω ◡)', '(´｡• ᵕ •｡`)', '(◕ᴗ◕✿)',
    '(ﾉ◕ヮ◕)ﾉ', '(≧∇≦)', '(＾▽＾)', '(◉‿◉)', '(´∇｀)', '(◕‿◕)♡'
  ],
  'sad': [
    '(´；ω；｀)', '(｡•́︿•̀｡)', '(╥_╥)', '(T_T)', '(;_;)', '(ಥ﹏ಥ)',
    '(இ﹏இ`｡)', '(┳Д┳)', '(个_个)', '(´-ω-`)', '(｡•́ - •̀｡)',
    '(╯︵╰)', '(｡╯︵╰｡)', '(´°̥̥̥̥̥̥̥̥ω°̥̥̥̥̥̥̥̥｀)', '(｡•́︿•̀｡)', '(◞‸◟)',
    '(╥﹏╥)', '(ಥ_ಥ)', '(´；д；`)', '(｡•́︿•̀｡)', '(╯_╰)', '(´Д｀)'
  ],
  'angry': [
    '(╬ಠ益ಠ)', '(ಠ_ಠ)', '(¬_¬)', '(►_►)', '(҂◡_◡)', '(ꐦ°᷄д°᷅)',
    '(╯°□°）╯︵ ┻━┻', '(ノಠ益ಠ)ノ', '(눈_눈)', '(⋋▂⋌)', '(-_-メ)',
    '(｀皿´＃)', '(╯‵□′)╯︵┻━┻', '(ﾉ｀Д´)ﾉ彡┻━┻', '(ಠ益ಠ)', '(◣_◢)',
    '(╬⁽⁽ ⁰ ⁾⁾ Д ⁽⁽ ⁰ ⁾⁾)', '(ﾉ°益°)ﾉ', '(｀ε´)', '(ﾉ｀⌒´)ﾉ┫：・┻┻', '(ﾒ｀ﾛ´)/', '(ﾉ｀□´)ﾉ⌒┻━┻'
  ],
  'love': [
    '(｡♥‿♥｡)', '(´∀｀)♡', '(◍•ᴗ•◍)❤', '(｡・//ε//・｡)', '(๑˃̵ᴗ˂̵)و',
    '(✿◠‿◠)', '(⺣◡⺣)♡*', '(灬º‿º灬)♡', '(ღ˘⌣˘ღ)', '(♥ω♥*)', '(´ε｀ )',
    '(´∀｀)♡', '(◕‿◕)♡', '(｡♥‿♥｡)', '(◍•ᴗ•◍)♡', '(´｡• ω •｡`) ♡',
    '(◡ ‿ ◡)♡', '(´∀｀)♡', '(◕ᴗ◕)♡', '(◍•ᴗ•◍)❤', '(´♡‿♡`)', '(◕‿◕)♡'
  ],
  'surprise': [
    '(゜o゜;)', '(O_O)', '(⊙_⊙)', '(°ロ°)', '(◎_◎;)', '(✪ω✪)',
    '(⊙ω⊙)', '(◉_◉)', '(°△°|||)', '(☉_☉)', '(ʘᗩʘ)',
    '(⊙０⊙)', '(◉０◉)', '(°o°)', '(⊙.⊙)', '(◎０◎)', '(°□°)',
    '(⊙▽⊙)', '(◉‿◉)', '(°▽°)', '(⊙ω⊙)', '(◎_◎)', '(°０°)'
  ],
  'emoji': [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊',
    '😇', '🥰', '😍', '🤩', '😘', '😗', '☺️', '😚', '😙', '🥲', '😋', '😛',
    '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑',
    '😶', '😏', '😒', '🙄', '😬', '🤥', '😔', '😪', '🤤', '😴', '😷', '🤒'
  ],
  'cute': [
    '(◕‿◕)', '(◡ ω ◡)', '(´｡• ᵕ •｡`)', '(◕ᴗ◕✿)', '(´꒳`)', '(◠‿◠)',
    '(｡◕‿◕｡)', '(◕‿◕)♡', '(◍•ᴗ•◍)', '(´∀｀)', '(◡‿◡)', '(◕ω◕)',
    '(◉‿◉)', '(◕‿◕)✿', '(◍•ᴗ•◍)✧*', '(◕‿◕)♪', '(◡ ‿ ◡)', '(◕‿◕)☆',
    '(◍•ᴗ•◍)♡', '(◕‿◕)♫', '(◡ ω ◡)♡', '(◕‿◕)✨', '(◍•ᴗ•◍)♪', '(◕‿◕)♬'
  ],
  'cool': [
    '(⌐■_■)', '(▀̿Ĺ̯▀̿ ̿)', '(◣_◢)', '(¬‿¬)', '(ಠ_ಠ)', '(¬_¬)',
    '(►_►)', '(◉_◉)', '(⊙_⊙)', '(◎_◎)', '(°_°)', '(-_-)',
    '(¯\\_(ツ)_/¯)', '(╯°□°）╯', '(ಠ益ಠ)', '(◣_◢)', '(⌐■_■)',
    '(▀̿Ĺ̯▀̿ ̿)', '(¬‿¬)', '(ಠ_ಠ)', '(¬_¬)', '(►_►)', '(◉_◉)', '(⊙_⊙)'
  ],
};

// ========== 可复用表情选择面板（iOS 18 风格，评论/消息共用）==========

/// 可复用的颜文字/Emoji 选择面板（两级 SegmentedControl + 网格）
/// 用于评论输入、消息界面等，统一数据与样式，便于维护。
class EmojiSelectorPanel extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  /// 选中后是否触发关闭（如评论里选中即关 overlay，消息里可选关）
  final VoidCallback? onClose;

  const EmojiSelectorPanel({
    super.key,
    required this.onEmojiSelected,
    this.onClose,
  });

  @override
  State<EmojiSelectorPanel> createState() => _EmojiSelectorPanelState();
}

class _EmojiSelectorPanelState extends State<EmojiSelectorPanel> {
  String _emojiMainCategory = 'kaomoji';
  String _kaomojiSubCategory = 'happy';

  void _onSelect(String emoji) {
    widget.onEmojiSelected(emoji);
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isEmoji = _emojiMainCategory == 'emoji';
    final currentList = isEmoji
        ? kKaomojis['emoji']!
        : (kKaomojis[_kaomojiSubCategory] ?? kKaomojis['happy']!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedControl<String>(
            segments: const ['kaomoji', 'emoji'],
            selectedSegment: _emojiMainCategory,
            onSegmentChanged: (v) => setState(() => _emojiMainCategory = v),
            labelBuilder: (v) => v == 'kaomoji' ? '颜文字' : 'Emoji',
            height: 28,
            fontSize: 12,
          ),
          const SizedBox(height: 10),
          if (!isEmoji) ...[
            SegmentedControl<String>(
              segments: kKaomojiSubKeys,
              selectedSegment: _kaomojiSubCategory,
              onSegmentChanged: (v) => setState(() => _kaomojiSubCategory = v),
              labelBuilder: (k) => kEmojiTabLabels[k]!,
              height: 26,
              fontSize: 11,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 160,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isEmoji ? 6 : 3,
                childAspectRatio: isEmoji ? 1.0 : 2.0,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: currentList.length,
              itemBuilder: (context, index) {
                final item = currentList[index];
                return GestureDetector(
                  onTap: () => _onSelect(item),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(fontSize: isEmoji ? 20 : 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 对外使用的颜文字/表情选择器（消息等场景）==========

/// 颜文字/表情选择器组件（内部使用 [EmojiSelectorPanel]）
class EmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback? onClose;

  const EmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return EmojiSelectorPanel(
      onEmojiSelected: onEmojiSelected,
      onClose: onClose,
    );
  }
}

/// 表情选择器按钮组件 - 用于在输入框旁边显示
class EmojiPickerButton extends StatefulWidget {
  final TextEditingController controller;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const EmojiPickerButton({
    super.key,
    required this.controller,
    this.size = 32,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<EmojiPickerButton> createState() => _EmojiPickerButtonState();
}

class _EmojiPickerButtonState extends State<EmojiPickerButton> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _removeOverlay();
    super.dispose();
  }

  /// 仅移除 overlay，不调用 setState
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    if (_isDisposed) return;
    _removeOverlay();

    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 点击外部关闭
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // 表情选择器
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).size.height - position.dy + 8,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: EmojiPicker(
                onEmojiSelected: _insertEmoji,
                onClose: _hideOverlay,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _hideOverlay() {
    _removeOverlay();
    if (!_isDisposed && mounted) setState(() {});
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, emoji);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + emoji.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _overlayEntry != null;
    return Container(
      key: _buttonKey,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(widget.size / 2),
        border: Border.all(
          color: context.dividerColor,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _toggleOverlay,
        icon: Icon(Icons.emoji_emotions_outlined, size: widget.size * 0.5),
        color: isActive 
            ? (widget.activeColor ?? AppColors.primary) 
            : (widget.inactiveColor ?? context.textSecondaryColor),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
