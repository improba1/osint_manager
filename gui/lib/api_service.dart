import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = 'http://127.0.0.1:8000';

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
}