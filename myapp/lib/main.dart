import 'package:flutter/material.dart';

/// 앱 실행이 시작되는 진입점입니다.
///
/// [runApp]은 [MyApp]을 위젯 트리의 루트로 등록하고 화면 렌더링을 시작합니다.
/// 상태가 없는 위젯이므로 const 인스턴스를 전달합니다.
void main() {
  runApp(const MyApp());
}

/// 앱 전체의 테마와 첫 화면을 정의하는 최상위 위젯입니다.
///
/// 실행 중 이 위젯 자체에서 변경되는 값이 없으므로 [StatelessWidget]입니다.
class MyApp extends StatelessWidget {
  /// [key]는 Flutter가 위젯 트리에서 위젯을 식별할 때 사용합니다.
  const MyApp({super.key});

  /// 현재 설정으로 하위 위젯 트리를 구성합니다.
  ///
  /// 화면을 다시 그릴 때 반복 호출될 수 있으므로 화면 선언만 담당합니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 개발 모드의 DEBUG 리본을 숨깁니다.
      debugShowCheckedModeBanner: false,

      // 운영체제의 앱 전환 화면 등에서 사용할 앱 제목입니다.
      title: 'Flutter 첫 수업',

      // 하위 Material 위젯에 공통으로 적용되는 디자인 설정입니다.
      theme: ThemeData(
        // 파란색을 기준으로 조화로운 색상표를 자동 생성합니다.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        // 최신 Material Design 3 스타일을 사용합니다.
        useMaterial3: true,
      ),

      // 앱 실행 시 처음 표시할 화면입니다.
      home: const HomePage(),
    );
  }
}

/// 앱의 메인 화면입니다.
///
/// 화면 데이터가 자체적으로 변하지 않으므로 [StatelessWidget]을 사용합니다.
/// 버튼 안내 메시지의 상태는 [ScaffoldMessenger]가 별도로 관리합니다.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold는 앱 바와 본문을 배치하는 Material 화면의 기본 골격입니다.
    // Delphi의 TForm과 비슷한 최상위 화면 컨테이너로 볼 수 있습니다.
    return Scaffold(
      // 화면 상단의 제목 표시줄입니다.
      appBar: AppBar(
        title: const Text('Flutter 첫 수업'),
        centerTitle: true, // 제목을 가로 중앙에 배치합니다.
        backgroundColor: Colors.blue,
        // 앱 바 위 제목과 아이콘의 기본 색상입니다.
        foregroundColor: Colors.white,
      ),

      // Column 전체를 본문 정중앙에 배치합니다.
      body: Center(
        child: Column(
          // Column의 주축은 세로이므로 자식들을 세로 중앙에 모읍니다.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // const 위젯은 내용이 변하지 않아 Flutter가 재사용할 수 있습니다.
            const Text(
              '안녕하세요',
              style: TextStyle(
                fontSize: 40,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),

            // 두 위젯 사이에 20 논리 픽셀의 세로 여백을 만듭니다.
            // 논리 픽셀은 화면 밀도가 달라도 비슷한 크기로 표시됩니다.
            const SizedBox(height: 20),

            const Text(
              'Flutter입니다',
              style: TextStyle(fontSize: 30, color: Colors.blue),
            ),

            const SizedBox(height: 20),

            const Text(
              'Delphi → Flutter',
              style: TextStyle(fontSize: 22, color: Colors.green),
            ),

            // 텍스트 그룹과 버튼 사이에는 더 넓은 여백을 둡니다.
            const SizedBox(height: 40),

            ElevatedButton(
              // 사용자가 버튼을 누를 때 실행되는 콜백입니다.
              onPressed: () {
                // context 위쪽의 ScaffoldMessenger를 찾아 화면 아래에
                // 잠시 나타났다가 사라지는 안내 메시지를 표시합니다.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('버튼을 눌렀습니다')),
                );
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}
