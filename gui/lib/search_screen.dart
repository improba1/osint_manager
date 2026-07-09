import 'package:flutter/material.dart';
import 'package:osint_frontend/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _searchResult;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSINT Search Engine'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Enter username'),
            ),
            const SizedBox( height: 16 ),

            _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton( 
              onPressed: () async {
                if (_usernameController.text.isEmpty){
                  return;
                }else{
                  setState(() {
                    _isLoading = true;
                  });
                  final results = await ApiService().searchByUsername(_usernameController.text);
                  setState(() {
                    _searchResult = results;
                    _isLoading = false;
                  });
                  print(results);
                }
              }, 
            child: const Text('Search') ),
            const SizedBox(height: 20,),

            if(_searchResult != null)
              Expanded(
                child: ListView.builder(
                  itemCount: (_searchResult!['results'] as List).length,
                  itemBuilder: (context, index){
                    final site = _searchResult!['results'][index];
                    return ListTile(
                      title: Text(site['service_name'] ?? 'Unknown'),
                      subtitle: Text(site['url'] ?? ''),
                      trailing: Text(site['status'] ?? ''),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
}