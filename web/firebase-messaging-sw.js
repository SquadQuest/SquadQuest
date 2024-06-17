// notificationclick handler must be installed before FCM is loaded
// - see: https://stackoverflow.com/questions/66224762/notificationclick-is-not-fired-for-remote-notifications
self.addEventListener('notificationclick', function (event) {
  console.log('notificationclick received: ', event.notification, event.data);

  const { fcmMessageId, data } = event.notification.data?.FCM_MSG;

  // skip non-data notifications
  if (!data) {
    return;
  }

  const { url: incomingUrl } = data;

  // parse url field in data
  if (!incomingUrl) {
    return;
  }
  const url = new URL(incomingUrl);

  // modify host if needed to support development
  if (location.host != url.host) {
    url.host = location.host;
  }

  // close handled notification
  event.notification.close();

  // look for existing window/tab with the target URL's hostname to send a message to, or open the URL
  event.waitUntil(
    clients.matchAll({ includeUncontrolled: true, type: 'window' }).then(windowClients => {
      for (client of windowClients) {
        console.log(`checking ${client.url} against ${url.href}`);

        if (new URL(client.url).host === url.host && 'focus' in client) {
          console.log('found! navigating and switching focus...');

          client.postMessage({
            messageType: 'notification-clicked',
            messageId: fcmMessageId,
            data: { urlHash: url.hash, ...data }
          });

          return client.focus();
        }
      }

      // open URL in new window if no existing window was found to message
      if (clients.openWindow) {
        console.log('Going to open window: ', url.href);
        return clients.openWindow(url.href); // TODO: uncomment
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

// must be called even if we're not using the messaging interface here
const messaging = firebase.messaging();


// all done
console.log('firebase-messaging-sw.js loaded!');
