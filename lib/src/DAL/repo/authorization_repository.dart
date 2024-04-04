import 'package:http/http.dart' as http;
import 'package:linkedin_login/src/DAL/api/exceptions.dart';
import 'package:linkedin_login/src/DAL/api/linked_in_api.dart';
import 'package:linkedin_login/src/utils/logger.dart';
import 'package:linkedin_login/src/wrappers/authorization_code_response.dart';

class AuthorizationRepository {
  AuthorizationRepository({required this.api});

  final LinkedInApi api;

  Future<AuthorizationCodeResponse> fetchAccessTokenCode({
    required final String redirectedUrl,
    required final String? clientSecret,
    required final String? clientId,
    required final String clientState,
    required final http.Client client,
  }) async {
    log(
      'LinkedInAuth-steps:fetchAccessTokenCode: parsing authorization code...',
    );
    final authorizationCode = _getAuthorizationCode(
      redirectedUrl,
      clientState,
    );
    log(
      'LinkedInAuth-steps:fetchAccessTokenCode: parsing authorization code... '
      'DONE, isEmpty: ${authorizationCode.code!.isEmpty}'
      ' \n LinkedInAuth-steps:fetchAccessTokenCode: fetching access token...',
    );

    final tokenObject = await api.login(
      redirectUrl: redirectedUrl.split('?')[0],
      clientId: clientId,
      authCode: authorizationCode.code,
      clientSecret: clientSecret,
      client: client,
    );

    log(
      'LinkedInAuth-steps:fetchAccessTokenCode: fetching access token... DONE',
    );

    authorizationCode.accessToken = tokenObject;

    return authorizationCode;
  }

  AuthorizationCodeResponse fetchAuthorizationCode({
    required final String redirectedUrl,
    required final String clientState,
  }) {
    return _getAuthorizationCode(redirectedUrl, clientState);
  }

  /// Method will parse redirection URL to get authorization code from
  /// query parameters. If there is an error property inside
  /// [AuthorizationCodeResponse] object will be populate
  AuthorizationCodeResponse _getAuthorizationCode(
    final String url,
    final String clientState,
  ) {
    final List<String> parseUrl = url.split('?');

    if (parseUrl.isNotEmpty) {
      Map<String, String> queryParams = getQueryParameters(url);



      if (queryParams['code'] != null && queryParams['code']!.isNotEmpty) {
        final List<String> codePart = ['code', queryParams['code']!];
        final List<String> statePart = [];
        if(queryParams.containsKey('state')) {
          statePart.addAll(['state', queryParams['state']!]);
        }

        if (_isAuthUrlEmpty(codePart, statePart)) {
          throw AuthCodeException(
            authCode: 'N/A',
            description: 'Cannot parse code ($codePart) or state ($statePart)',
          );
        }

        if (statePart[1] == clientState) {
          final test = AuthorizationCodeResponse(
            code: codePart[1],
            state: statePart[1],
          );

          return test;
        } else {
          throw AuthCodeException(
            authCode: statePart[1],
            description:
                'Current auth code is different from initial one: $clientState',
          );
        }
      }
      else if (queryParams['error'] != null && queryParams['error']!.isNotEmpty) {
        String errorValue = queryParams['error']!.replaceAll('+', ' ');
        String? anotherKey = (queryParams.keys.toList()..remove("error")).firstOrNull;
        String anotherValue = anotherKey != null ? queryParams[anotherKey]! : "N/A";

        throw AuthCodeException(
          authCode: anotherValue,
          description: errorValue,
        );
      }
    }

    throw AuthCodeException(
      authCode: 'N/A',
      description: 'Cannot parse url: $url',
    );
  }

  bool _isAuthUrlEmpty(
    final List<String> code,
    final List<String> state,
  ) {
    return code.length < 2 ||
        state.length < 2 ||
        code[1].isEmpty ||
        state[1].isEmpty;
  }

  Map<String, String> getQueryParameters(String path) {
    print("AuthorizationRepository().getQueryParameters() called with path:'$path'");

    final Map<String, String> queryParams = <String, String>{};
    if (path.contains('?')) {
      path = path.substring(path.indexOf('?'));
      path = path.replaceAll('?', '');

      final List<String> parameters = path.split('&');
      for (String parameterString in parameters) {
        final List<String> values = parameterString.split('=');
        if (values.isNotEmpty) {
          queryParams[values.first] = values.elementAtOrNull(1) ?? '';
        }
      }
    }
    print('Final queryParams:$queryParams');

    return queryParams;
  }
}
