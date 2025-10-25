// lib/main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // package http đơn giản (GET/POST...)
import 'package:dio/dio.dart'; // dio: interceptor, retry, options...
import 'dart:convert'; // jsonEncode/jsonDecode

void main() => runApp(
      const MaterialApp(
        home: ApiDemo(),
        debugShowCheckedModeBanner: false,
      ),
    );

/// Stateful widget chính (UI + state để load & hiển thị dữ liệu)
class ApiDemo extends StatefulWidget {
  const ApiDemo({super.key});
  @override
  State<ApiDemo> createState() => _ApiDemoState();
}

class _ApiDemoState extends State<ApiDemo> {
  // --- State: chứa dữ liệu trả về từ 2 package ---
  List postsHttp = [], postsDio = []; // store JSON list from each client
  String timeHttp = '', timeDio = ''; // store measured durations (ms)

  // --- Khởi tạo Dio với interceptor ---
  // Interceptor ở đây dùng để: log request, bắt lỗi, và thử retry khi là lỗi kết nối.
  // Chúng ta đặt interceptor ngay khi tạo Dio instance.
  final dio = Dio(BaseOptions(headers: {'Authorization': 'Bearer fake_token'}))
    ..interceptors.add(InterceptorsWrapper(
      // onRequest: chạy trước khi gửi request - dùng để log / inject token / delay giả lập...
      onRequest: (o, h) {
        debugPrint(' [Dio] GET ${o.uri}'); // in log để debug
        return h.next(o); // tiếp tục chuỗi request
      },
      // onError: xử lý khi có lỗi xảy ra trong quá trình request/response
      onError: (e, h) async {
        debugPrint(' [Dio] Error: ${e.message}');
        // Nếu là lỗi kết nối (ví dụ tắt mạng), thử retry một lần
        if (e.type == DioExceptionType.connectionError) {
          debugPrint(' Retry...');
          try {
            // gửi lại request cũ với cấu hình requestOptions
            final retry = await Dio().fetch(e.requestOptions);
            return h.resolve(retry); // nếu retry ok thì resolve với response mới
          } catch (e2) {
            debugPrint(' Retry thất bại: $e2');
            return h.next(e); // nếu retry thất bại thì trả lỗi
          }
        }
        return h.next(e); // các lỗi khác thì chuyển tiếp
      },
    ));

  // --- Hàm gọi API bằng package:http ---
  // Đo thời gian, parse JSON, cập nhật state (setState)
  Future<void> getHttp() async {
    final t0 = DateTime.now(); // bắt đầu đo thời gian
    try {
      final r = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        headers: {'Authorization': 'Bearer fake_token'}, // ví dụ header auth
      );
      if (r.statusCode == 200) {
        setState(() {
          postsHttp = jsonDecode(r.body); // decode JSON string -> List/Map
          timeHttp = '${DateTime.now().difference(t0).inMilliseconds} ms'; // tính ms
        });
      } else {
        // status non-200: log để debug (có thể hiển thị lên UI nếu cần)
        debugPrint('HTTP non-200: ${r.statusCode}');
      }
    } catch (e) {
      // catch network/parse exceptions
      debugPrint(' HTTP Error: $e');
    }
  }

  // --- Hàm gọi API bằng Dio ---
  // Dio tự parse JSON (res.data) và trả về object tương đương
  Future<void> getDio() async {
    final t0 = DateTime.now();
    try {
      final r = await dio.get('https://jsonplaceholder.typicode.com/posts');
      setState(() {
        postsDio = r.data;
        timeDio = '${DateTime.now().difference(t0).inMilliseconds} ms';
      });
    } catch (e) {
      debugPrint(' Dio Error: $e');
    }
  }

  // --- Gọi API khi widget khởi tạo ---
  @override
  void initState() {
    super.initState();
    getHttp(); // gọi http
    getDio(); // gọi dio
  }

  // --- Build UI: hiển thị thời gian + danh sách post + nút reload ---
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('HTTP vs Dio')),
        body: postsHttp.isEmpty && postsDio.isEmpty
            ? const Center(child: CircularProgressIndicator()) // loading spinner
            : ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  // Hiển thị thời gian và vài thông tin cho HTTP
                  Text('HTTP (${timeHttp}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...postsHttp.map((p) => Text('${p['id']}. ${p['title']}')), // show title list

                  const Divider(),

                  // Hiển thị thời gian và danh sách cho Dio
                  Text('Dio (${timeDio}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...postsDio.map((p) => Text('${p['id']}. ${p['title']}')),

                  const SizedBox(height: 12),

                  // Nút reload: gọi lại cả 2 API
                  ElevatedButton(
                    onPressed: () {
                      getHttp();
                      getDio();
                    },
                    child: const Text('Reload'),
                  ),
                ],
              ),
      );
} 