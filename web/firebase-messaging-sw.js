// notificationclick handler must be installed before FCM is loaded
// - see: https://stackoverflow.com/questions/66224762/notificationclick-is-not-fired-for-remote-notifications
self.addEventListener('notificationclick', function (event) {
  const { url: incomingUrl } = event.notification.data?.FCM_MSG?.data;

  console.log('notificationclick received: ', event.notification.title, incomingUrl, event);

  if (!incomingUrl) {
    return;
  }

  const url = new URL(incomingUrl);

  // modify host if needed to support development
  if (location.host != url.host) {
    url.host = location.host;
  }

  event.notification.close(); // Android needs explicit close.
  event.waitUntil(
    clients.matchAll({ includeUncontrolled: true, type: 'window' }).then(windowClients => {
      for (client of windowClients) {
        // Check if there is already a window/tab open with the target URL
        console.log(`checking ${client.url} against ${url.href}`);
        if (new URL(client.url).host === url.host && 'focus' in client) {
          // If so, just focus it.
          console.log('found! navigating and switching focus...');
          client.postMessage({
            action: 'redirect-from-notificationclick',
            hash: url.hash,
          })
          return client.focus();
        }
      }

      // If not, then open the target URL in a new window/tab.
      if (clients.openWindow) {
        console.log('Going to open window: ', url.href);
        // return clients.openWindow(url.href);
      }
    })
  );
});


// claim the current window for this serviceworker immediately
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));


// load FCM
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


// configure background message handler for FCM remote messages
messaging.onBackgroundMessage(function (payload) {
  console.log('Received background message ', payload);

  const payloadData = payload.data.json && JSON.parse(payload.data.json);
  console.log('Parsed payload data ', payloadData);

  // post notification locally
  // const promiseChain = clients
  //   .matchAll({
  //     type: "window",
  //     includeUncontrolled: true
  //   })
  //   .then(windowClients => {
  //     for (client of windowClients) {
  //       client.postMessage(payload);
  //     }
  //   })
  //   .then(() => {
  //     const title = 'SW: ' + payload.notification.title;
  //     const options = {
  //       body: payload.notification.body,
  //       icon: '/icons/Icon-192.png',
  //       data: { ...payloadData, url: payload.data.url }
  //     };
  //     console.log(`Showing notification: ${title}`, options);
  //     return registration.showNotification(title, options);
  //   });
  // return promiseChain;
});


// all done
console.log('firebase-messaging-sw.js loaded!');
