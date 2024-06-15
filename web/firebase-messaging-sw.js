importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
    apiKey: "AIzaSyA87qGDgjT9CSoW2skUs-af-qsF5oU0-X0",
    authDomain: "squadquest-d8665.firebaseapp.com",
    projectId: "squadquest-d8665",
    storageBucket: "squadquest-d8665.appspot.com",
    messagingSenderId: "902139539375",
    appId: "1:902139539375:web:8ffb7afcec26c91c77c95a",
    measurementId: "G-HCYKP80G02"
  };

firebase.initializeApp(firebaseConfig);

// Necessary to receive background messages:
const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((m) => {
  console.log("onBackgroundMessage", m);
});
