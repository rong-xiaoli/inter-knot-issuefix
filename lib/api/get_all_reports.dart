import 'dart:async';

import 'package:inter_knot/api/is_discussion_available.dart';

import 'common.dart';
import '../data.dart';

Future<Report> getAllReports(int number) async {
  final res = <({String login, Set<int> numbers, String bodyHTML})>[];
  String? after;
  while (true) {
    final data = await graphql(
        '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 100, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { author { login } body bodyHTML } } } } }');
    if (data.data
        case {
          'data': {
            'repository': {
              'discussion': {
                'comments': {
                  'pageInfo': {
                    'hasNextPage': final bool hasNextPage,
                    'endCursor': final String endCursor
                  },
                  'nodes': final List<dynamic> nodes
                }
              }
            }
          }
        }) {
      res.addAll(nodes
          .map((e) {
            if (e
                case {
                  'author': {
                    'login': final String login,
                  },
                  'body': final String body,
                  'bodyHTML': final String bodyHTML,
                }) {
              return (login: login, bodyHTML: bodyHTML, body: body);
            }
            return null;
          })
          .whereType<({String login, String bodyHTML, String body})>()
          .map((e) {
            if (!e.body.contains('原因')) return null;
            final numbers = RegExp(r'#(\d+)')
                .allMatches(e.body)
                .map((e) => e.group(1))
                .whereType<String>()
                .map((e) => int.parse(e))
                .toSet();
            if (numbers.isEmpty) return null;
            return (
              login: e.login,
              bodyHTML: e.bodyHTML,
              numbers: numbers,
            );
          })
          .whereType<({String login, Set<int> numbers, String bodyHTML})>());
      if (!hasNextPage) break;
      after = endCursor;
    }
  }
  final t = await Future.wait(transformReports(res)
      .entries
      .map((e) => isDiscussionAvailable(e.key).then((v) => v ? e : null))
      .toList());
  return Map.fromEntries(t.whereType<MapEntry<int, Set<ReportComment>>>());
}

typedef Report = Map<int, Set<ReportComment>>;

class ReportComment {
  final String login;
  final String bodyHTML;
  late final url = 'https://github.com/$login';

  ReportComment({required this.login, required this.bodyHTML});

  @override
  operator ==(Object other) =>
      other is ReportComment &&
      other.login == login &&
      other.bodyHTML == bodyHTML;

  @override
  int get hashCode => login.hashCode ^ bodyHTML.hashCode;
}

Report transformReports(
    List<({String login, Set<int> numbers, String bodyHTML})> arr) {
  final Report obj = {};
  for (final i in arr) {
    for (final num in i.numbers) {
      if (obj[num] == null) {
        obj[num] = {ReportComment(login: i.login, bodyHTML: i.bodyHTML)};
      } else if (!obj[num]!.map((e) => e.login).contains(i.login)) {
        obj[num]!.add(ReportComment(login: i.login, bodyHTML: i.bodyHTML));
      }
    }
  }
  return obj;
}
