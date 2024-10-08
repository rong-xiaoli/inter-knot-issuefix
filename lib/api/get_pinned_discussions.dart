import 'dart:async';

import 'common.dart';
import '../data.dart';

Future<Nodes<Article>> getPinnedDiscussions(String? after) async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "$repo") { pinnedDiscussions(first: 20, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { discussion { number author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } } } } }');
  if (res.data
      case {
        'data': {
          'repository': {
            'pinnedDiscussions': {
              'nodes': final List<dynamic> nodes,
              'pageInfo': {
                'hasNextPage': final bool hasNextPage,
                'endCursor': final String endCursor
              },
            },
          },
        }
      }) {
    return (
      res: nodes
          .map((e) {
            if (e
                case {
                  'discussion': {
                    'author': {
                      'avatarUrl': final String avatar,
                      'login': final String name,
                    },
                    'id': final String id,
                    'bodyHTML': final String bodyHTML,
                    'bodyText': final String bodyText,
                    'title': final String title,
                    'number': final int number,
                    'createdAt': final String createdAt,
                    'lastEditedAt': final String? lastEditedAt,
                    'comments': {
                      'totalCount': final int commentsCount,
                    },
                  }
                }) {
              final (:html, :cover, :partition) = parseHtml(bodyHTML);
              return Article(
                title: title,
                bodyHTML: html,
                rawBodyText: bodyText,
                author: Author(avatar: avatar, login: name),
                cover: cover,
                number: number,
                id: id,
                createdAt: DateTime.parse(createdAt),
                lastEditedAt: lastEditedAt == null
                    ? null
                    : DateTime.tryParse(lastEditedAt),
                commentsCount: commentsCount,
                isPin: true,
                partition: partition!,
              );
            }
          })
          .whereType<Article>()
          .toList(),
      hasNextPage: hasNextPage,
      endCursor: endCursor
    );
  }
  return (res: <Article>[], hasNextPage: false, endCursor: null);
}
