// Service worker that lets the browser show a system notification for FCM
// pushes that arrive while this site isn't open/focused. Auto-registered by
// the firebase_messaging Flutter web plugin (it looks for this exact path).
//
// TODO(push-notifications): fill in the same values used in
// lib/firebase_options.dart (Firebase Console > Project Settings > General
// > "Your apps" > the registered Web app's config). Keep the two in sync.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAC-GB_Sqjr2a-Ie1dwkkkfDWInHeT6yUQ',
  appId: '1:148406608884:web:8a7c1b6009aee1d5ce4fa1',
  messagingSenderId: '148406608884',
  projectId: 'fomrahrms',
  authDomain: 'fomrahrms.firebaseapp.com',
  storageBucket: 'fomrahrms.firebasestorage.app',
});

// No onBackgroundMessage handler needed — the SDK auto-renders the
// `notification` payload FCM sends (title/body) as a system notification.
firebase.messaging();
