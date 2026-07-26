// 测试文件
import 'package:flutter_test/flutter_test.dart';
import 'package:zhuyapp/main.dart';

void main() {
  testWidgets('竹芽 App 启动测试', (WidgetTester tester) async {
    await tester.pumpWidget(const ZhuyApp());
    await tester.pump();
    expect(find.text('竹  芽'), findsOneWidget);
  });
}
