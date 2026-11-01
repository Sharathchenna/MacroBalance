import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:macrotracker/utils/user_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('UserError.messageFor', () {
    test('no internet reads as offline, however it arrives', () {
      final offline = <Object>[
        const SocketException('Failed host lookup: mdivtblabmnftdqlgysv.supabase.co'),
        TimeoutException('took too long'),
        http.ClientException('Connection closed before full header was received'),
        // What Supabase auth throws with no connection: a very long message.
        AuthRetryableFetchException(
            message: 'ClientException with SocketException: Failed host lookup: '
                "'mdivtblabmnftdqlgysv.supabase.co' (OS Error: No address associated "
                'with hostname, errno = 7), uri=https://mdivtblabmnftdqlgysv.supabase.co/auth/v1/token'),
        Exception('An unexpected error occurred during password reset: '
            'ClientException with SocketException: Failed host lookup'),
      ];
      for (final error in offline) {
        expect(UserError.messageFor(error), UserError.offline, reason: '$error');
      }
    });

    test('plain auth messages are kept', () {
      expect(UserError.messageFor(const AuthException('Invalid login credentials')),
          'Invalid login credentials');
      expect(UserError.messageFor(const AuthException('Email not confirmed')),
          'Email not confirmed');
    });

    test('long or technical auth messages are not', () {
      expect(UserError.messageFor(const AuthException('PostgrestException(message: boom)')),
          UserError.generic);
      expect(UserError.messageFor(AuthException('x' * 200)), UserError.generic);
    });

    test('anything else gets the fallback, or the generic line', () {
      final error = StateError('Bad state: null check operator used on a null value');
      expect(UserError.messageFor(error), UserError.generic);
      expect(UserError.messageFor(error, fallback: "Couldn't save your workout."),
          "Couldn't save your workout.");
    });

    test('the offline line wins over the fallback', () {
      expect(
          UserError.messageFor(const SocketException('Network is unreachable'),
              fallback: "Couldn't save your workout."),
          UserError.offline);
    });
  });

  test('describe returns the same words and never throws while reporting', () {
    expect(
        UserError.describe(const SocketException('Network is unreachable'),
            where: 'test', stack: StackTrace.current),
        UserError.offline);
  });
}
