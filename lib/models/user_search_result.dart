/// フレンド検索結果の最小データ。`FriendService.searchByDisplayName`が
/// 返す、`users/{uid}`ドキュメントのうち必要な2フィールドだけ。
class UserSearchResult {
  final String uid;
  final String displayName;

  const UserSearchResult({required this.uid, required this.displayName});
}
