from pathlib import Path
import re
import sqlite3

source = Path('C:/Users/user/Downloads/ContractList_%EA%B3%84%EC%95%BD%EC%9D%BC%EC%9E%90%EC%A0%95%EB%A0%AC_20261008.php')
out = Path(__file__).resolve().parent / 'ContractList_fixed_20261009.php'
original = source.read_text(encoding='utf-8-sig')
start = original.index('// 2025-10-28 기준일자')
end = original.index('\tif(Trim($SortType) == 1)', start)
replacement = '''// 2026-10-09 기본 정렬 기준일. 해당 날짜(2025-09-01)도 이후 그룹에 포함합니다.
$BaseMaxDate = '2025-09-01';

// 열 제목을 클릭하지 않은 경우에만 기본 정렬을 만듭니다.
if (Trim($GridTitleClickField) == '')
{
    // 아래 변수는 날짜 값이 아니라 SQL Server에서 계산할 SQL 표현식입니다.
    // NULL, 일반 공백, 탭, 줄바꿈을 정리한 값을 모든 날짜 판정에서 공통 사용합니다.
    $ContractDateSortValue = "REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(a.ContractDate,''), ' ', ''), CHAR(9), ''), CHAR(13), ''), CHAR(10), '')";
    // 빈 값 또는 하이픈만 남은 값은 미입력입니다. 날짜의 길이보다 먼저 판정합니다.
    $ContractDateMissing = "REPLACE($ContractDateSortValue, '-', '') = ''";

    // 기존 첫 번째 CASE의 의도를 유지하되, 공백 날짜가 길이 10으로 오분류되는 문제를 수정합니다.
    // 그룹 0: 기준일 이후 등록 + 계약일자 미입력
    // 그룹 1: 길이 10 이상인 계약일자(등록일 무관), 또는 기준일 이후의 짧은 계약일자
    // 그룹 2: 기준일 이전 등록 + 짧은 계약일자 또는 미입력
    // 각 그룹에서는 길이 10 이상 / 연월 등 짧은 입력 / 미입력을 구분합니다.
    // 날짜 입력값은 기존처럼 YYYY-MM-DD 또는 YYYY-MM 형식이라는 전제입니다.
    // 길이 구분은 달력상 유효한 날짜를 검증하는 기능은 아닙니다.
    // 계약일자가 같거나 모두 미입력이면 수정일자 최신순, 이어서 PK_ID 큰 순입니다.
    $strSort = " ORDER BY
        CASE
            WHEN a.RegDate >= '$BaseMaxDate' AND ($ContractDateMissing)
                THEN 0
            WHEN NOT ($ContractDateMissing) AND LEN($ContractDateSortValue) >= 10
                THEN 1
            WHEN a.RegDate >= '$BaseMaxDate'
                THEN 1
            ELSE 2
        END ASC,
        CASE
            WHEN ($ContractDateMissing) THEN 2
            WHEN LEN($ContractDateSortValue) >= 10 THEN 0
            ELSE 1
        END ASC,
        CASE
            WHEN ($ContractDateMissing) THEN NULL
            ELSE $ContractDateSortValue
        END DESC,
        a.EditDate DESC,
        a.PK_ID DESC ";

    // 以下の既存処理: 정렬 메뉴 1~9 선택 시 위 기본 정렬을 선택 정렬로 대체합니다.
'''.replace('以下の既存処理: ', '')
modified = original[:start] + replacement + original[end:]
# 표준 PHP 시작 태그를 사용하여 short_open_tag 설정에 의존하지 않습니다.
modified = re.sub(r'<\?(?=\s)', '<?php', modified)
# 행 번호에 맞는 실제 반환 순서도 보장합니다.
old = '$strSQL .= " Where RowNum BETWEEN {$StartCount} AND {$EndCount}";'
new = '$strSQL .= " Where RowNum BETWEEN {$StartCount} AND {$EndCount} ORDER BY RowNum ASC";'
assert modified.count(old) == 1
modified = modified.replace(old, new)
out.write_bytes(modified.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8'))

# 생성된 PHP의 정렬 표현식을 SQLite의 동등 함수로 평가합니다.
# SQL Server 서버 실행을 대체하지 않으며, CASE 우선순위의 예시 검증입니다.
value = "REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(a.ContractDate,''), ' ', ''), CHAR(9), ''), CHAR(13), ''), CHAR(10), '')"
missing = f"REPLACE({value}, '-', '') = ''"
sort = modified.split('$strSort = " ORDER BY\n', 1)[1].split('";', 1)[0]
sort = sort.replace('$BaseMaxDate', '2025-09-01').replace('$ContractDateMissing', missing).replace('$ContractDateSortValue', value)
sort = sort.replace('ISNULL(', 'IFNULL(').replace('LEN(', 'LENGTH(')
db = sqlite3.connect(':memory:')
db.execute('CREATE TABLE contracts(PK_ID INTEGER, RegDate TEXT, ContractDate TEXT, EditDate TEXT)')
fixtures = [
 (101,'2025-09-01',None,'2026-10-09'),
 (102,'2026-10-01','    -  -  ','2026-10-08'),
 (103,'2026-10-01',' \t\r\n','2026-10-07'),
 (104,'2025-08-20','2026-10-08','2026-10-01'),
 (105,'2026-10-01','2026-10-08','2026-10-02'),
 (106,'2026-10-01','2026-10','2026-10-09'),
 (107,'2025-08-20','2026-11','2026-10-09'),
 (108,'2025-08-20',None,'2026-10-09'),
 (109,'2025-08-20','2026-10-08','2026-10-02'),
 (110,'2026-10-01','2026-10-07','2026-10-09'),
 (111,'2026-10-01','---','2026-10-06'),
]
db.executemany('INSERT INTO contracts VALUES(?,?,?,?)', fixtures)
actual = [r[0] for r in db.execute('SELECT PK_ID FROM contracts a ORDER BY '+sort)]
expected = [101,102,103,111,109,105,104,110,106,107,108]
assert actual == expected, (actual, expected)
assert 'table_contract_belji b WITH(NOLOCK)' in modified
assert original[original.index('// 2026-10-08 계약서 및 별지'):original.index('/*\n//5년전 계약서')] == modified[modified.index('// 2026-10-08 계약서 및 별지'):modified.index('/*\n//5년전 계약서')]
assert '$strSort\t= "order By $GridTitleClickField' in modified
assert not re.search(r'<\?(?=\s)', modified)
print('Generated:', out)
print('PASS: 11-row ordering fixture, cutoff boundary, blank/hyphen values, month-only values, EditDate and PK ties')
print('PASS: unified search and title-click sorting preserved; outer ORDER BY added; standard PHP tags')
