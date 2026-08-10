// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌 App Widget 测试
//
// 测试内容：
//   - 启动 App（ZhuyApp）
//   - 验证页面上能找到品牌文字 "竹  笌"
//
// 运行命令：
//   flutter test
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter_test/flutter_test.dart';
import 'package:zhuyapp/main.dart';

void main() {
  testWidgets('竹笌 App 启动测试', (WidgetTester tester) async {
    // 加载根 Widget，触发 build
    await tester.pumpWidget(const ZhuyApp());
    // 等待所有异步任务和动画完成一帧
    await tester.pump();
    // 断言：页面上存在且仅存在一个 "竹  笌" 文本
    expect(find.text('竹  笌'), findsOneWidget);
  });
}
