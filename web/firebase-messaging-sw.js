importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyA87qGDgjT9CSoW2skUs-af-qsF5oU0-X0",
  authDomain: "squadquest-d8665.firebaseapp.com",
  projectId: "squadquest-d8665",
  storageBucket: "squadquest-d8665.appspot.com",
  messagingSenderId: "902139539375",
  appId: "1:902139539375:web:8ffb7afcec26c91c77c95a",
  measurementId: "G-HCYKP80G02"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const promiseChain = clients
    .matchAll({
      type: "window",
      includeUncontrolled: true
    })
    .then(windowClients => {
      for (let i = 0; i < windowClients.length; i++) {
        const windowClient = windowClients[i];
        windowClient.postMessage(payload);
      }
    })
    .then(() => {
      const title = payload.notification.title;
      const options = {
        body: payload.notification.body
      };
      console.log(`Showing push notification: ${title}`, options);
      return registration.showNotification(title, options);
    });
  return promiseChain;
});

self.addEventListener('notificationclick', function (event) {
  console.log('notification received: ', event)
});
