import 'dart:async';

import 'boost_model.dart';
import 'boost_service.dart';

class BoostController {
  final BoostService service;

  BoostController({
    BoostService? service,
  }) : service = service ?? BoostService();

  bool isLoading = false;
  String? errorMessage;

  List<BoostModel> boosts = [];

  StreamSubscription<List<BoostModel>>? _boostSubscription;

  Future<String?> createBoost({
    required String videoId,
    required int budget,
    required int durationDays,
  }) async {
    isLoading = true;
    errorMessage = null;

    try {
      final boostId = await service.createBoost(
        videoId: videoId,
        budget: budget,
        durationDays: durationDays,
      );

      return boostId;
    } catch (e) {
      errorMessage = _cleanError(e);
      return null;
    } finally {
      isLoading = false;
    }
  }

  Future<BoostModel?> getBoost(String boostId) async {
    isLoading = true;
    errorMessage = null;

    try {
      return await service.getBoost(boostId);
    } catch (e) {
      errorMessage = _cleanError(e);
      return null;
    } finally {
      isLoading = false;
    }
  }

  Future<void> loadMyBoosts() async {
    isLoading = true;
    errorMessage = null;

    try {
      boosts = await service.getMyBoosts();
    } catch (e) {
      errorMessage = _cleanError(e);
    } finally {
      isLoading = false;
    }
  }

  void watchMyBoosts({
    required void Function(List<BoostModel> items) onChanged,
  }) {
    _boostSubscription?.cancel();

    _boostSubscription = service.watchMyBoosts().listen(
      (items) {
        boosts = items;
        errorMessage = null;
        onChanged(items);
      },
      onError: (Object error) {
        errorMessage = _cleanError(error);
      },
    );
  }

  Future<bool> cancelBoost(String boostId) async {
    isLoading = true;
    errorMessage = null;

    try {
      await service.cancelBoost(boostId);

      await loadMyBoosts();

      return true;
    } catch (e) {
      errorMessage = _cleanError(e);
      return false;
    } finally {
      isLoading = false;
    }
  }

  Future<bool> updateBoostStatus({
    required String boostId,
    required String status,
  }) async {
    isLoading = true;
    errorMessage = null;

    try {
      await service.updateBoostStatus(
        boostId: boostId,
        status: status,
      );

      return true;
    } catch (e) {
      errorMessage = _cleanError(e);
      return false;
    } finally {
      isLoading = false;
    }
  }

  Future<bool> incrementImpressions(String boostId) async {
    try {
      await service.incrementImpressions(boostId);
      return true;
    } catch (e) {
      errorMessage = _cleanError(e);
      return false;
    }
  }

  Future<bool> incrementClicks(String boostId) async {
    try {
      await service.incrementClicks(boostId);
      return true;
    } catch (e) {
      errorMessage = _cleanError(e);
      return false;
    }
  }

  void clearError() {
    errorMessage = null;
  }

  void dispose() {
    _boostSubscription?.cancel();
    _boostSubscription = null;
  }

  String _cleanError(Object error) {
    final message = error.toString();

    switch (message) {
      case 'Exception: LOGIN_REQUIRED':
        return 'প্রথমে লগইন করুন';

      case 'Exception: VIDEO_ID_REQUIRED':
        return 'ভিডিও নির্বাচন করুন';

      case 'Exception: INVALID_BUDGET':
        return 'সঠিক Boost budget দিন';

      case 'Exception: INVALID_DURATION':
        return 'সঠিক Boost duration নির্বাচন করুন';

      case 'Exception: BOOST_NOT_FOUND':
        return 'Boost পাওয়া যায়নি';

      case 'Exception: NOT_AUTHORIZED':
        return 'এই Boost পরিবর্তন করার অনুমতি নেই';

      case 'Exception: INVALID_STATUS':
        return 'Boost status সঠিক নয়';

      default:
        return message
            .replaceFirst('Exception: ', '')
            .replaceFirst('Error: ', '');
    }
  }
}
