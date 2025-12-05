// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// class LanguageSelectionScreen extends StatelessWidget {
//   const LanguageSelectionScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Select Language'),
//       ),
//       body: ListView(
//         children: [
//           ListTile(
//             title: const Text('English'),
//             onTap: () {
//               Provider.of<LanguageProvider>(context, listen: false)
//                   .setLocale(const Locale('en'));
//               Navigator.pop(context);
//             },
//           ),
//           ListTile(
//             title: const Text('Spanish'),
//             onTap: () {
//               Provider.of<LanguageProvider>(context, listen: false)
//                   .setLocale(const Locale('es'));
//               Navigator.pop(context);
//             },
//           ),
//           ListTile(
//             title: const Text('French'),
//             onTap: () {
//               Provider.of<LanguageProvider>(context, listen: false)
//                   .setLocale(const Locale('fr'));
//               Navigator.pop(context);
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
