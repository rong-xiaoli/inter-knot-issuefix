import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:html/parser.dart';
import 'package:logger/logger.dart';

import 'get_access_token.dart';
import '../data.dart';

final c = Get.find<Controller>();
final logger = Logger();

var canRequest = true;

final dio = Dio(BaseOptions(
  responseType: ResponseType.json,
  headers: {'accept': 'application/json'},
  baseUrl: 'https://api.github.com',
))
  ..interceptors.addAll([
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (canRequest) {
          logger.d('Request: ${options.uri}\nData: ${options.data}');
          return handler.next(options);
        } else {
          return handler.reject(DioException.requestCancelled(
              requestOptions: options, reason: 'RATE_LIMITED'));
        }
      },
      onResponse: (response, handler) async {
        logger.d(
            'Response: ${response.requestOptions.uri}\nResponse: ${response.data}');
        if (response.data['errors']?[0]?['type'] == 'RATE_LIMITED') {
          showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: Text('Error: API rate limit reached'.tr),
                content: SelectableText('Please try again later'.tr),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('OK'.tr),
                  ),
                ],
              );
            },
          );
          canRequest = false;
          await Future.delayed(60.s);
          canRequest = true;
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        logger.e(
          'Error: ${error.requestOptions.uri}\nResponse: ${error.response?.data}',
          error: error,
          stackTrace: error.stackTrace,
        );
        // final msg =
        //     'Error: ${error.requestOptions.uri}\n\nResponse:\n${error.response?.data}\n\nError Object:\n$error\n\nStack Trace:\n${error.stackTrace}';
        // showDialog(
        //   context: Get.context!,
        //   builder: (context) {
        //     return AlertDialog(
        //       title: Text('Error: ${error.requestOptions.uri}'),
        //       content: SelectableText(msg),
        //       actions: [
        //         FeedbackBtn(msg),
        //         TextButton(
        //           onPressed: () => Get.back(),
        //           child: Text('OK'.tr),
        //         ),
        //       ],
        //     );
        //   },
        // );
        return handler.next(error);
      },
    ),
  ]);

Future<Response<T>> request<T>(
  String url, {
  Object? data,
  Map<String, dynamic>? queryParameters,
  Options? options,
}) async {
  options ??= Options();
  options.headers ??= {};
  var delay = 0.5.s;
  while (true) {
    options.headers!['Authorization'] = 'Bearer ${c.getToken()}';
    try {
      return await dio.request<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        try {
          final accessToken = await getAccessToken();
          await c.setToken(accessToken);
          continue;
        } catch (e, s) {
          logger.e('Failed to get access token', error: e, stackTrace: s);
        }
      }
    }
    await Future.delayed(delay);
    delay += 0.5.s;
  }
}

Future<Response<Map<String, dynamic>>> graphql(String data) async =>
    request('/graphql',
        data: jsonEncode({'query': data}), options: Options(method: 'POST'));

String encode(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\r', '\\r')
    .replaceAll('\n', '\\n');

typedef Nodes<T> = ({List<T> res, bool hasNextPage, String? endCursor});

({
  String html,
  String? cover,
  String? partition,
}) parseHtml(String html, [bool isComment = false]) {
  final document = parseFragment(html);
  if (!isComment) {
    final img = document.querySelector('img');
    final cover = img?.attributes['src'];
    img?.remove();
    var parent = img?.parent;
    while (parent != null && parent.nodes.isEmpty) {
      parent.remove();
      parent = parent.parent;
    }
    var partition = '';
    document.querySelectorAll('h3').forEach((e) {
      if (e.text.trim() == '分区') {
        if (e.nextElementSibling?.text is String) {
          partition = e.nextElementSibling!.text;
          e.nextElementSibling!.remove();
        }
        e.remove();
      }
      if (e.text.trim() == '封面') e.remove();
      if (e.text.trim() == '内容') e.remove();
    });
    document.querySelectorAll('p>em:only-child').forEach((e) {
      if (e.text.trim() == 'No response') e.parent!.remove();
    });
    return (html: document.outerHtml, cover: cover, partition: partition);
  }
  document.querySelectorAll('.email-hidden-toggle').forEach((e) => e.remove());
  document.querySelectorAll('.email-hidden-reply').forEach((e) => e.remove());
  return (html: document.outerHtml, cover: null, partition: null);
}
