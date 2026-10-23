/// 2026-09-27 로마자(영문 자판) 입력을 히라가나로 바꾼다.
/// 일본어 키보드가 없는 사용자도 "sukoshi" → "すこし"처럼 쉽게 입력할 수 있게 한다.
class Romaji {
  Romaji._();

  static const Map<String, String> _table = <String, String>{
    'a': 'あ', 'i': 'い', 'u': 'う', 'e': 'え', 'o': 'お',
    'ka': 'か', 'ki': 'き', 'ku': 'く', 'ke': 'け', 'ko': 'こ',
    'sa': 'さ', 'si': 'し', 'shi': 'し', 'su': 'す', 'se': 'せ', 'so': 'そ',
    'ta': 'た', 'ti': 'ち', 'chi': 'ち', 'tu': 'つ', 'tsu': 'つ', 'te': 'て', 'to': 'と',
    'na': 'な', 'ni': 'に', 'nu': 'ぬ', 'ne': 'ね', 'no': 'の',
    'ha': 'は', 'hi': 'ひ', 'hu': 'ふ', 'fu': 'ふ', 'he': 'へ', 'ho': 'ほ',
    'ma': 'ま', 'mi': 'み', 'mu': 'む', 'me': 'め', 'mo': 'も',
    'ya': 'や', 'yu': 'ゆ', 'yo': 'よ',
    'ra': 'ら', 'ri': 'り', 'ru': 'る', 're': 'れ', 'ro': 'ろ',
    'la': 'ら', 'li': 'り', 'lu': 'る', 'le': 'れ', 'lo': 'ろ',
    'wa': 'わ', 'wi': 'うぃ', 'we': 'うぇ', 'wo': 'を',
    'ga': 'が', 'gi': 'ぎ', 'gu': 'ぐ', 'ge': 'げ', 'go': 'ご',
    'za': 'ざ', 'zi': 'じ', 'ji': 'じ', 'zu': 'ず', 'ze': 'ぜ', 'zo': 'ぞ',
    'da': 'だ', 'di': 'ぢ', 'du': 'づ', 'de': 'で', 'do': 'ど',
    'ba': 'ば', 'bi': 'び', 'bu': 'ぶ', 'be': 'べ', 'bo': 'ぼ',
    'pa': 'ぱ', 'pi': 'ぴ', 'pu': 'ぷ', 'pe': 'ぺ', 'po': 'ぽ',
    'va': 'ゔぁ', 'vi': 'ゔぃ', 'vu': 'ゔ', 've': 'ゔぇ', 'vo': 'ゔぉ',
    'fa': 'ふぁ', 'fi': 'ふぃ', 'fe': 'ふぇ', 'fo': 'ふぉ',
    'kya': 'きゃ', 'kyu': 'きゅ', 'kyo': 'きょ',
    'sya': 'しゃ', 'syu': 'しゅ', 'syo': 'しょ', 'sha': 'しゃ', 'shu': 'しゅ', 'sho': 'しょ', 'she': 'しぇ',
    'tya': 'ちゃ', 'tyu': 'ちゅ', 'tyo': 'ちょ', 'cha': 'ちゃ', 'chu': 'ちゅ', 'cho': 'ちょ', 'che': 'ちぇ',
    'cya': 'ちゃ', 'cyu': 'ちゅ', 'cyo': 'ちょ',
    'nya': 'にゃ', 'nyu': 'にゅ', 'nyo': 'にょ',
    'hya': 'ひゃ', 'hyu': 'ひゅ', 'hyo': 'ひょ',
    'mya': 'みゃ', 'myu': 'みゅ', 'myo': 'みょ',
    'rya': 'りゃ', 'ryu': 'りゅ', 'ryo': 'りょ',
    'lya': 'りゃ', 'lyu': 'りゅ', 'lyo': 'りょ',
    'gya': 'ぎゃ', 'gyu': 'ぎゅ', 'gyo': 'ぎょ',
    'zya': 'じゃ', 'zyu': 'じゅ', 'zyo': 'じょ', 'ja': 'じゃ', 'ju': 'じゅ', 'jo': 'じょ', 'je': 'じぇ',
    'jya': 'じゃ', 'jyu': 'じゅ', 'jyo': 'じょ',
    'dya': 'ぢゃ', 'dyu': 'ぢゅ', 'dyo': 'ぢょ',
    'bya': 'びゃ', 'byu': 'びゅ', 'byo': 'びょ',
    'pya': 'ぴゃ', 'pyu': 'ぴゅ', 'pyo': 'ぴょ',
    'thi': 'てぃ', 'dhi': 'でぃ', 'tsa': 'つぁ',
    'xa': 'ぁ', 'xi': 'ぃ', 'xu': 'ぅ', 'xe': 'ぇ', 'xo': 'ぉ',
    'xya': 'ゃ', 'xyu': 'ゅ', 'xyo': 'ょ', 'xtu': 'っ', 'xtsu': 'っ', 'xwa': 'ゎ',
    '-': 'ー',
  };

  static final Set<String> _prefixes = <String>{
    for (final key in _table.keys)
      for (var i = 1; i <= key.length; i++) key.substring(0, i),
  };

  static bool _isVowel(String c) => 'aiueo'.contains(c);
  static bool _isAsciiLetter(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x61 && code <= 0x7A;
  }

  /// 2026-09-27 입력 문자열의 로마자 부분을 히라가나로 바꾼다.
  /// [finalize]가 false면 아직 끝나지 않은 글자(예: 끝의 "k", "n", "sh")는 로마자 그대로 둔다.
  /// 이미 가나·한자로 된 부분은 건드리지 않는다.
  static String toHiragana(String input, {bool finalize = false}) {
    final text = input.toLowerCase();
    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (!_isAsciiLetter(c) && c != '-' && c != "'") {
        out.write(input[i]);
        i++;
        continue;
      }
      final next = i + 1 < text.length ? text[i + 1] : null;

      // ん 처리: nn, n', n + 자음
      if (c == 'n') {
        if (next == null) {
          out.write(finalize ? 'ん' : 'n');
          i++;
          continue;
        }
        if (next == "'") {
          out.write('ん');
          i += 2;
          continue;
        }
        if (next == 'n') {
          // "konnichiha"처럼 nn 뒤에 모음/y가 오면 앞 n만 ん이 되고 뒤 n은 다음 글자(に)가 된다.
          final after = i + 2 < text.length ? text[i + 2] : null;
          out.write('ん');
          i += (after != null && (_isVowel(after) || after == 'y')) ? 1 : 2;
          continue;
        }
        if (!_isVowel(next) && next != 'y' && _isAsciiLetter(next)) {
          out.write('ん');
          i++;
          continue;
        }
      }

      // 촉음(っ): 같은 자음 두 번 (kka → っか)
      if (next != null && c == next && _isAsciiLetter(c) && !_isVowel(c) && c != 'n') {
        out.write('っ');
        i++;
        continue;
      }
      // tch → っち
      if (c == 't' && next == 'c') {
        out.write('っ');
        i++;
        continue;
      }

      String? matched;
      var matchedLength = 0;
      for (var length = 4; length >= 1; length--) {
        if (i + length > text.length) continue;
        final piece = text.substring(i, i + length);
        final kana = _table[piece];
        if (kana != null) {
          matched = kana;
          matchedLength = length;
          break;
        }
      }
      if (matched != null) {
        out.write(matched);
        i += matchedLength;
        continue;
      }

      final rest = text.substring(i);
      if (!finalize && _prefixes.contains(rest)) {
        // 아직 입력 중인 글자(예: "ky", "sh")는 그대로 둔다.
        out.write(input.substring(i));
        break;
      }
      if (c == "'") {
        i++;
        continue;
      }
      out.write(input[i]);
      i++;
    }
    return out.toString();
  }
}
