"""창작 일기 원고에 후리가나와 사전형을 붙인다. 기사 수집·AI 호출은 하지 않는다."""
import json
from pathlib import Path
from news_build import tokens_of, merge_plain

path = Path(__file__).resolve().parent.parent / 'assets/news/haru_diary.json'
entries = json.loads(path.read_text(encoding='utf-8'))
for entry in entries:
    entry['titleTokens'] = merge_plain(tokens_of(entry['title'], {}))
    entry['tokens'] = [merge_plain(tokens_of(sentence[0], {})) for sentence in entry['sentences']]
path.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'{len(entries)} diary episodes annotated')
