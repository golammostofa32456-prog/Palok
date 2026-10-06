import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'friend_model.dart';
import 'friends_service.dart';

class FriendsController extends ChangeNotifier {
  FriendsController({
    FriendsService? service,
    FirebaseAuth? auth,
  })  : _service = service ?? FriendsService(),
        _auth = auth ?? FirebaseAuth.instance;

  final FriendsService _service;
  final FirebaseAuth _auth;

  List<FriendModel> _suggestedCreators = [];
  List<FriendModel> _following = [];

  bool _isLoading = false;
  String? _error;

  List<FriendModel> get suggestedCreators =>
      List.unmodifiable(_suggestedCreators);

  List<FriendModel> get following =>
      List.unmodifiable(_following);

  bool get isLoading => _isLoading;

  String? get error => _error;

  User? get currentUser => _auth.currentUser;

  Future<void> loadFriends() async {
    final user = _auth.currentUser;

    if (user == null) {
      _error = 'Login করতে হবে';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getSuggestedCreators(
          currentUserId: user.uid,
        ),
        _service.getFollowing(
          currentUserId: user.uid,
        ),
      ]);

      _suggestedCreators = results[0];
      _following = results[1];

      // যাদের already follow করা হয়েছে তাদের Suggested
      // list থেকে বাদ দিই।
      final followingIds = _following
          .map((friend) => friend.userId)
          .toSet();

      _suggestedCreators = _suggestedCreators
          .where(
            (friend) => !followingIds.contains(friend.userId),
          )
          .toList();
    } catch (e) {
      _error = 'Creator লোড করা যায়নি';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(FriendModel friend) async {
    final user = _auth.currentUser;

    if (user == null) {
      _error = 'Follow করতে Login করতে হবে';
      notifyListeners();
      return;
    }

    if (friend.userId.isEmpty || friend.userId == user.uid) {
      return;
    }

    try {
      await _service.toggleFollow(
        currentUserId: user.uid,
        friend: friend,
      );

      if (friend.isFollowing) {
        _following = _following
            .where(
              (item) => item.userId != friend.userId,
            )
            .toList();

        final updated = friend.copyWith(
          isFollowing: false,
        );

        _suggestedCreators = [
          ..._suggestedCreators,
          updated,
        ];
      } else {
        _suggestedCreators = _suggestedCreators
            .where(
              (item) => item.userId != friend.userId,
            )
            .toList();

        _following = [
          ..._following,
          friend.copyWith(
            isFollowing: true,
          ),
        ];
      }

      notifyListeners();
    } catch (e) {
      _error = 'Follow পরিবর্তন করা যায়নি';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
