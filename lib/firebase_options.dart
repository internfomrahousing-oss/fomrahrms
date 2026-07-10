import 'package:firebase_core/firebase_core.dart';

/// Web needs its Firebase config passed explicitly in Dart (there's no
/// google-services.json equivalent read at build time for web); Android
/// reads its config natively from android/app/google-services.json instead,
/// so [FirebaseOptions] are only needed here for the web target.
///
/// TODO(push-notifications): fill in from Firebase Console > Project
/// Settings > General > "Your apps" > the registered Web app's config.
const FirebaseOptions webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAC-GB_Sqjr2a-Ie1dwkkkfDWInHeT6yUQ',
  appId: '1:148406608884:web:8a7c1b6009aee1d5ce4fa1',
  messagingSenderId: '148406608884',
  projectId: 'fomrahrms',
  authDomain: 'fomrahrms.firebaseapp.com',
  storageBucket: 'fomrahrms.firebasestorage.app',
);

/// Firebase Console > Project Settings > Cloud Messaging > Web Push
/// certificates > key pair.
const String webPushVapidKey =
    'BEpSKOBIX3rTjPU6K3IhZ4AlJEg6QC6dawYwIHGet22ykI7QB4dAdCZxdhw3qWUexh8NUxHjCaMrzej4C4HqsQA';
