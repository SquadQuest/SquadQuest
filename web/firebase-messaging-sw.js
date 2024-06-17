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
  console.log('Received background message ', payload);

  const payloadData = payload.data.json && JSON.parse(payload.data.json);
  console.log('Parsed payload data ', payloadData);

  const promiseChain = clients
    .matchAll({
      type: "window",
      includeUncontrolled: true
    })
    .then(windowClients => {
      for (client of windowClients) {
        client.postMessage(payload);
      }
    })
    .then(() => {
      const title = payload.notification.title;
      const options = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png',
        data: payloadData
      };
      console.log(`Showing notification: ${title}`, options);
      return registration.showNotification(title, options);
    });
  return promiseChain;
});

self.addEventListener('notificationclick', function (event) {
  console.log('notificationclick received: ', event);

  const url = `https://cwqvpckp-80.use.devtunnels.ms/#/events/${event.notification.data.event.id}`;

  event.notification.close(); // Android needs explicit close.
  event.waitUntil(
    clients.matchAll({ includeUncontrolled: true, type: 'window' }).then(windowClients => {
      for (client of windowClients) {
        // Check if there is already a window/tab open with the target URL
        console.log(`looking for ${url} in ${client.url}`);
        if (client.url === url && 'focus' in client) {
          // If so, just focus it.
          console.log('found! switching focus...');
          return client.focus();
        }
      }

      // If not, then open the target URL in a new window/tab.
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});

// claim the current window immediately
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));

console.log('firebase-messaging-sw.js loaded!');
