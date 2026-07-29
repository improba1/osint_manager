import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  final String baseUrl = 'http://127.0.0.1:8000';
  final String wsUrl = 'ws://127.0.0.1:8000';

  Stream<Map<String, dynamic>> _liveSearchStream(String endpoint, Map<String, dynamic> payload) async* {
    final channel = WebSocketChannel.connect(Uri.parse('$wsUrl$endpoint'));
    
    channel.sink.add(jsonEncode(payload));

    await for (var message in channel.stream) {
      try {
        yield Map<String, dynamic>.from(jsonDecode(message));
      } catch (e) {
        yield {'status': 'ERROR', 'error_message': 'Parsing error: $e'};
      }
    }
  }

  Stream<Map<String, dynamic>> liveUsernameSearch(String username) {
    return _liveSearchStream('/api/username', {'username': username});
  }

  Stream<Map<String, dynamic>> liveEmailLeaksSearch(String email) {
    return _liveSearchStream('/api/email', {'email': email});
  }

  Future<Map<String, dynamic>> searchByUsername(String username) async {
    try{
      final response = await http.post(
        Uri.parse('$baseUrl/api/username'),
        headers: {'Content-Type' : 'application/json'},
        body : jsonEncode({'username' : username}),
      );
      if (response.statusCode == 200){
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        return decodedData;
      } else {
        return {'status': 'error', 'error_message' : 'Internal Server Error'};
      }
    } catch (e){
      return {'status': 'error', 'error_message' : e.toString()};
    }
  }


  Future<Map<String, dynamic>> _postEmailRequest(String endpoint, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'error_message': 'Server Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'error_message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkEmailDisposable(String email) async {
    return await _postEmailRequest('/api/email/disposable', email);
  }

  Future<Map<String, dynamic>> checkEmailValidate(String email) async {
    return await _postEmailRequest('/api/email/validate', email);
  }

  Future<Map<String, dynamic>> checkEmailGravatar(String email) async {
    return await _postEmailRequest('/api/email/gravatar', email);
  }

  Future<Map<String, dynamic>> checkEmailHolehe(String email) async {
    return await _postEmailRequest('/api/email/holehe', email);
  }

  Future<Map<String, dynamic>> checkEmailLeaks(String email) async {
    try{
      final response = await http.post(
        Uri.parse('$baseUrl/api/email'),
        headers: {'Content-Type' : 'application/json'},
        body : jsonEncode({'email' : email}),
      );
      if (response.statusCode == 200){
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        return decodedData;
      } else {
        return {'status': 'error', 'error_message' : 'Internal Server Error'};
      }
    } catch (e){
      return {'status': 'error', 'error_message' : e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> _postPhoneRequest(String endpoint, String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'error_message': 'Server Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'error_message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkPhoneValid(String phone) async => await _postPhoneRequest('/api/phone/valid', phone);
  Future<Map<String, dynamic>> checkPhoneCountry(String phone) async => await _postPhoneRequest('/api/phone/country', phone);
  Future<Map<String, dynamic>> checkPhoneDorks(String phone) async => await _postPhoneRequest('/api/phone/dorks', phone);
  Future<Map<String, dynamic>> checkPhoneViber(String phone) async => await _postPhoneRequest('/api/phone/viber/chat', phone);
  Future<Map<String, dynamic>> checkPhoneTelegramChat(String phone) async => await _postPhoneRequest('/api/phone/telegram/chat', phone);
  Future<Map<String, dynamic>> checkPhoneWhatsapp(String phone) async => await _postPhoneRequest('/api/phone/whatsapp/chat', phone);
  Future<Map<String, dynamic>> checkPhoneTelegramProfile(String phone) async => await _postPhoneRequest('/api/phone/telegram', phone);
}