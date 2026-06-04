import 'package:alper_cursor_remote/state/inbound/inbound_bucket_resolver.dart';
import 'package:alper_cursor_remote/state/session_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 5, 29, 10);
  final t1 = t0.add(const Duration(seconds: 5));

  test('tek bekleyen: wire yanlış olsa bile gönderim bucket’ı kazanır', () {
    const musicLocal = 'loc-music';
    const msgMusic = 'u-music';
    final waiting = [
      WaitingDispatch(
        bucketKey: musicLocal,
        localMessageId: msgMusic,
        waitingSince: t0,
      ),
    ];
    final dispatch = {msgMusic: musicLocal};

    expect(
      resolveInboundBucketKey(
        wireSessionId: 'wrong-pc-uuid',
        waiting: waiting,
        dispatchBucketByLocalMessageId: dispatch,
      ),
      musicLocal,
    );
  });

  test('iki bekleyen: wire ikinciye ait değilse en eski (müzik) kazanır', () {
    const musicLocal = 'loc-music';
    const pending = 'loc-yuruk';
    const msgMusic = 'u-music';
    const msgYuruk = 'u-yuruk';
    final waiting = [
      WaitingDispatch(
        bucketKey: musicLocal,
        localMessageId: msgMusic,
        waitingSince: t0,
      ),
      WaitingDispatch(
        bucketKey: pending,
        localMessageId: msgYuruk,
        waitingSince: t1,
      ),
    ];
    final dispatch = {
      msgMusic: musicLocal,
      msgYuruk: pending,
    };

    expect(
      resolveInboundBucketKey(
        wireSessionId: 'pc-music-uuid',
        waiting: waiting,
        dispatchBucketByLocalMessageId: dispatch,
      ),
      musicLocal,
    );
  });

  test('yalnız yürük bekliyor: wire yürük id → pending kutusu', () {
    const pending = 'loc-yuruk';
    const pcYuruk = 'pc-yuruk-uuid';
    const msgYuruk = 'u-yuruk';
    final waiting = [
      WaitingDispatch(
        bucketKey: pending,
        localMessageId: msgYuruk,
        waitingSince: t1,
      ),
    ];
    final dispatch = {msgYuruk: pending};

    expect(
      resolveInboundBucketKey(
        wireSessionId: pcYuruk,
        waiting: waiting,
        dispatchBucketByLocalMessageId: dispatch,
      ),
      pending,
    );
  });

  test('pickSessionRenameSource: pending’de yürük varken müzik cevabı local’e bağlanır', () {
    const musicLocal = 'loc-music';
    const pending = 'loc-yuruk';
    const msgMusic = 'u-music';
    const msgYuruk = 'u-yuruk';
    final waiting = [
      WaitingDispatch(
        bucketKey: musicLocal,
        localMessageId: msgMusic,
        waitingSince: t0,
      ),
      WaitingDispatch(
        bucketKey: pending,
        localMessageId: msgYuruk,
        waitingSince: t1,
      ),
    ];
    final dispatch = {
      msgMusic: musicLocal,
      msgYuruk: pending,
    };

    expect(
      pickSessionRenameSourceKey(
        targetBucketKey: 'pc-music-uuid',
        waiting: waiting,
        dispatchBucketByLocalMessageId: dispatch,
        wireSessionId: 'pc-music-uuid',
        pendingHasChat: true,
      ),
      musicLocal,
    );
  });

  test('iki bekleyen varken pendingHasChat kör fallback yok', () {
    const musicLocal = 'loc-music';
    const pending = 'loc-yuruk';
    final waiting = [
      WaitingDispatch(
        bucketKey: musicLocal,
        localMessageId: 'u-music',
        waitingSince: t0,
      ),
      WaitingDispatch(
        bucketKey: pending,
        localMessageId: 'u-yuruk',
        waitingSince: t1,
      ),
    ];
    expect(
      pickSessionRenameSourceKey(
        targetBucketKey: 'pc-music-uuid',
        waiting: waiting,
        dispatchBucketByLocalMessageId: {
          'u-music': musicLocal,
          'u-yuruk': pending,
        },
        wireSessionId: 'pc-music-uuid',
        pendingHasChat: true,
      ),
      musicLocal,
    );
  });

  test('senaryo: cevap gelmeden 2. oturum — pendingHasChat tek başına yetmez', () {
    const musicLocal = 'loc-music';
    const msgMusic = 'u-music';
    final waiting = [
      WaitingDispatch(
        bucketKey: musicLocal,
        localMessageId: msgMusic,
        waitingSince: t0,
      ),
    ];
  final dispatch = {msgMusic: musicLocal};

    expect(
      pickSessionRenameSourceKey(
        targetBucketKey: 'pc-music-uuid',
        waiting: waiting,
        dispatchBucketByLocalMessageId: dispatch,
        wireSessionId: 'pc-music-uuid',
        pendingHasChat: true,
      ),
      musicLocal,
    );
  });
}
