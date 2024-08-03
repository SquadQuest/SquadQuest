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
runPreflightChecklist();


function runPreflightChecklist() {
  const isIos = /iphone|ipad|ipod/i.test(window.navigator.userAgent);
  const isInStandaloneMode = ('standalone' in window.navigator) && window.navigator.standalone;
  const addToHomescreenDeclined = localStorage.getItem('add-to-homescreen-declined');

  if (isIos && !isInStandaloneMode && !addToHomescreenDeclined) {
    showAddToHomeScreen();
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

async function launchFlutterApp() {
  console.log('Launching Flutter app...');

  // ensure all overlay content is hidden
  addToHomescreenCt.style.display = 'none';

  // wait for app runner to be ready
  const appRunner = await flutterAppRunnerPromise;

  // run app
  console.log('Running Flutter app...');
  await appRunner.runApp();

  // remove loading indicator
  document.body.classList.remove('loading');
}
