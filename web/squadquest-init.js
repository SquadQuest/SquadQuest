const flutterAppRunnerPromise = new Promise((resolve) => {
  console.log('Loading Flutter app...');
  _flutter.loader.load({
    onEntrypointLoaded: function (engineInitializer) {
      console.log('Initializing Flutter engine...');
      engineInitializer.initializeEngine().then(resolve);
    }
  });
});


// Pre-launch screens for mobile Safari
const addToHomescreenCt = document.getElementById('add-to-homescreen');
const requestNotificationPermissionCt = document.getElementById('request-notification-permission');
runPreflightChecklist();

function runPreflightChecklist() {
  const isIos = /iphone|ipad|ipod/i.test(window.navigator.userAgent);
  const isInStandaloneMode = ('standalone' in window.navigator) && window.navigator.standalone;
  const canRequestNotificationPermission = 'Notification' in window && Notification.permission != 'granted' && !localStorage.getItem('request-notification-permission-declined');
  const addToHomescreenDeclined = localStorage.getItem('add-to-homescreen-declined');

  if (isIos && !isInStandaloneMode && !addToHomescreenDeclined) {
    showAddToHomeScreen();
  } else if (isIos && isInStandaloneMode && canRequestNotificationPermission) {
    showRequestNotificationPermission();
  } else {
    launchFlutterApp();
  }
}

function showAddToHomeScreen() {
  addToHomescreenCt.style.display = 'block';

  document.getElementById('add-to-homescreen-decline').addEventListener('click', function (event) {
    event.preventDefault();
    localStorage.setItem('add-to-homescreen-declined', true);
    launchFlutterApp();
  });
}

function showRequestNotificationPermission() {
  requestNotificationPermissionCt.style.display = 'block';

  document.getElementById('request-notification-permission-launch').addEventListener('click', function (event) {
    event.preventDefault();
    requestNotificationPermissionCt.style.display = 'none';
    Notification.requestPermission().then(function (result) {
      // store result because mobile Safari will lie about Notification.permission until we request permission
      if (result == 'denied') {
        localStorage.setItem('request-notification-permission-declined', true);
      }

      launchFlutterApp();
    });
  });
}

async function launchFlutterApp() {
  console.log('Launching Flutter app...');

  // ensure all overlay content is hidden
  addToHomescreenCt.style.display = 'none';
  requestNotificationPermissionCt.style.display = 'none';

  // wait for app runner to be ready
  const appRunner = await flutterAppRunnerPromise;

  // run app
  console.log('Running Flutter app...');
  await appRunner.runApp();

  // remove loading indicator
  document.body.classList.remove('loading');
}
