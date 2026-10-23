import 'package:flutter/material.dart';
import 'package:kioku_japanese/pages/bunka_reading_pages.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/widgets/ruby_text.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

const List<int> _levels = <int>[5, 4, 3, 2, 1];

Color _levelColor(int level) => GradeColors.of('N$level').main;

/// 2026-10-01 쉬운 일본어 뉴스 목록. 날짜순(최신이 위)으로 기사를 보여준다.
class NewsListPage extends StatefulWidget {
  const NewsListPage(
      {super.key, required this.repository, required this.speakJapanese});

  final NewsRepository repository;
  final Future<void> Function(String text) speakJapanese;

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  List<NewsArticle>? _articles;
  bool _refreshing = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = await widget.repository.loadLocal();
    if (!mounted) return;
    setState(() => _articles = local);
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    if (widget.repository.feedUrl.isEmpty) return;
    setState(() => _refreshing = true);
    final fresh = await widget.repository.refresh();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _refreshFailed = fresh == null;
      if (fresh != null) _articles = fresh;
    });
  }

  @override
  Widget build(BuildContext context) {
    final articles = _articles;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: '하루의 일기', subtitle: '매일 오전 7시 · 한 편씩 · 총 365편'),
      body: articles == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  PaperCard(
                    key: const ValueKey('open-bunka-reading'),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const BunkaReadingListPage())),
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.menu_book_rounded,
                          color: Washi.shu, size: 32),
                      title: Text('문화 독해 · 40강',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('원어민 낭독 · 문장별 듣기 · 전체 해석 · 내용 확인 문제'),
                      trailing: Icon(Icons.chevron_right),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                          '하루는 도쿄의 작은 서점에서 일하는 24살입니다. 1년 동안의 일상을 함께 읽어 보세요.\n'
                          '첫 사용일부터 매일 오전 7시에 한 편씩 열리며, 모두 365편입니다. 인터넷이 없어도 읽을 수 있어요.',
                          style:
                              TextStyle(fontSize: 13, color: Washi.inkSoft))),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_refreshFailed)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '글을 불러오지 못했어요. 앱을 다시 열어 주세요.',
                        style: TextStyle(fontSize: 13, color: Washi.inkSoft),
                      ),
                    ),
                  if (articles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                          child: Text('오전 7시에 첫 일기가 열려요.',
                              style: TextStyle(color: Washi.inkSoft))),
                    ),
                  for (final a in articles) ...[
                    _ArticleCard(
                      article: a,
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => NewsArticlePage(
                            article: a, speakJapanese: widget.speakJapanese),
                      )),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: ValueKey('news-${article.id}'),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(article.date.replaceAll('-', '.'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Washi.shu)),
              const SizedBox(width: 8),
              if (article.category.isNotEmpty) _Chip(article.category),
              const Spacer(),
              _DistributionBar(
                  distribution: article.distribution, width: 80, height: 6),
            ],
          ),
          const SizedBox(height: 6),
          Text(article.titleText,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, color: Washi.ink)),
          const SizedBox(height: 2),
          Text(article.titleKorean,
              style: const TextStyle(fontSize: 14, color: Washi.inkSoft)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: Washi.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Washi.line),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
      );
}

/// N5~N1 단어 수를 색 막대로 그린다.
class _DistributionBar extends StatelessWidget {
  const _DistributionBar(
      {required this.distribution, this.width, this.height = 8});

  final Map<String, int> distribution;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total =
        _levels.fold<int>(0, (s, l) => s + (distribution['N$l'] ?? 0));
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: total == 0
            ? Container(color: Washi.line)
            : Row(
                children: [
                  for (final l in _levels)
                    if ((distribution['N$l'] ?? 0) > 0)
                      Expanded(
                          flex: distribution['N$l']!,
                          child: Container(color: _levelColor(l))),
                ],
              ),
      ),
    );
  }
}

/// 2026-10-01 기사 화면: 단어 분포, 제목·문단(후리가나, 급수 밑줄, 한국어 번역, 듣기), 핵심 단어.
/// 아래 떠 있는 버튼으로 후리가나 / 번역 / 밑줄을 켜고 끈다.
class NewsArticlePage extends StatefulWidget {
  const NewsArticlePage(
      {super.key, required this.article, required this.speakJapanese});

  final NewsArticle article;
  final Future<void> Function(String text) speakJapanese;

  @override
  State<NewsArticlePage> createState() => _NewsArticlePageState();
}

class _NewsArticlePageState extends State<NewsArticlePage> {
  bool _ruby = true;
  bool _korean = true;
  bool _underline = true;
  int? _selectedAnswer;

  void _showWord(NewsToken token) {
    showModalBottomSheet<void>(
        context: context,
        backgroundColor: Washi.paper,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(token.word ?? token.text,
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                      Text(token.reading, style: const TextStyle(fontSize: 20)),
                      Text(token.meaning, style: const TextStyle(fontSize: 22)),
                      if (token.level != null) Text('JLPT N${token.level}'),
                      _speak(token.word ?? token.text, 'word-popup-speak'),
                    ]))));
  }

  Widget _question(NewsQuestion question) {
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('읽고 확인하기',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(question.prompt, style: const TextStyle(fontSize: 18)),
      for (var i = 0; i < question.options.length; i++)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
                key: ValueKey('reading-answer-$i'),
                style: OutlinedButton.styleFrom(
                    disabledForegroundColor: Washi.ink,
                    backgroundColor:
                        _selectedAnswer != null && i == question.answer
                            ? Washi.shu.withValues(alpha: 0.12)
                            : null),
                onPressed: _selectedAnswer != null
                    ? null
                    : () => setState(() => _selectedAnswer = i),
                child: Text('${i + 1}. ${question.options[i]}'))),
      if (_selectedAnswer != null) ...[
        const SizedBox(height: 12),
        Text(
            _selectedAnswer == question.answer
                ? '정답이에요!'
                : '정답은 ${question.answer + 1}번이에요.',
            key: const ValueKey('reading-feedback'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(question.explanation),
      ],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: a.category.startsWith('하루') ? '하루의 일기' : '읽기',
          subtitle: a.date.replaceAll('-', '.')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
            children: [
              _distribution(a),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(a.date.replaceAll('-', '.'),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Washi.shu)),
                  const SizedBox(width: 8),
                  if (a.category.isNotEmpty) _Chip(a.category),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RubyText(
                      key: const ValueKey('news-title'),
                      tokens: a.title,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      showRuby: _ruby,
                      showUnderline: false,
                      onWordTap: _showWord,
                    ),
                  ),
                  _speak(a.titleText, 'news-speak-title'),
                ],
              ),
              if (_korean) ...[
                const SizedBox(height: 8),
                Text(a.titleKorean,
                    style: const TextStyle(
                        fontSize: 16, color: Washi.inkSoft, height: 1.5)),
              ],
              const SizedBox(height: 14),
              const Divider(color: Washi.line),
              for (var i = 0; i < a.paragraphs.length; i++) ...[
                Align(
                    alignment: Alignment.centerRight,
                    child: _speak(a.paragraphs[i].japanese, 'news-speak-$i')),
                RubyText(
                  key: ValueKey('news-paragraph-$i'),
                  tokens: a.paragraphs[i].tokens,
                  showRuby: _ruby,
                  showUnderline: _underline,
                  onWordTap: _showWord,
                ),
                if (_korean) ...[
                  const SizedBox(height: 10),
                  Text(
                    a.paragraphs[i].korean,
                    key: ValueKey('news-korean-$i'),
                    style: const TextStyle(
                        fontSize: 16, color: Washi.ink, height: 1.6),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(color: Washi.line),
              ],
              if (a.words.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('핵심 단어',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Washi.ink)),
                const SizedBox(height: 6),
                for (final w in a.words) _wordRow(w),
              ],
              if (a.question != null) ...[
                const SizedBox(height: 20),
                _question(a.question!),
              ],
              if (a.source.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(a.source,
                    style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(child: _toggles()),
          ),
        ],
      ),
    );
  }

  Widget _speak(String text, String key) => IconButton(
        key: ValueKey(key),
        tooltip: '듣기',
        icon: const Icon(Icons.volume_up_rounded, color: Washi.shu, size: 28),
        onPressed: () => widget.speakJapanese(text),
      );

  Widget _distribution(NewsArticle a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('JLPT 단어 분포',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: Washi.ink)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final l in _levels)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _levelColor(l), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('N$l: ${a.distribution['N$l'] ?? 0}',
                      key: ValueKey('news-dist-N$l'),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Washi.ink)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        _DistributionBar(distribution: a.distribution),
      ],
    );
  }

  Widget _wordRow(NewsWord w) {
    final color = _levelColor(w.level);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Washi.line))),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.japanese,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Washi.ink)),
                if (w.reading.isNotEmpty && w.reading != w.japanese)
                  Text(w.reading,
                      style:
                          const TextStyle(fontSize: 14, color: Washi.inkSoft)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(w.korean,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Washi.ink)),
              ),
              const SizedBox(height: 4),
              Text('N${w.level}',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          IconButton(
            tooltip: '듣기',
            icon: const Icon(Icons.volume_up_rounded,
                color: Washi.inkSoft, size: 22),
            onPressed: () => widget.speakJapanese(w.reading),
          ),
        ],
      ),
    );
  }

  Widget _toggles() {
    Widget button(
        String key, String label, IconData icon, bool on, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Material(
          color: on ? Washi.shu : Washi.card,
          shape: CircleBorder(
              side: BorderSide(color: on ? Washi.shu : Washi.line)),
          child: InkWell(
            key: ValueKey(key),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: on ? Colors.white : Washi.ink),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : Washi.ink)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Washi.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Washi.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('news-toggle-ruby', '후리가나', Icons.subtitles_rounded, _ruby,
              () => setState(() => _ruby = !_ruby)),
          button('news-toggle-korean', '번역', Icons.translate_rounded, _korean,
              () => setState(() => _korean = !_korean)),
          button(
              'news-toggle-underline',
              '급수 밑줄',
              Icons.format_underlined_rounded,
              _underline,
              () => setState(() => _underline = !_underline)),
        ],
      ),
    );
  }
}
