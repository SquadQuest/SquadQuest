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
const welcomeCt = document.getElementById('welcome');
const addToHomescreenCt = document.getElementById('add-to-homescreen');
const isIos = /iphone|ipad|ipod/i.test(window.navigator.userAgent);
const isInStandaloneMode = ('standalone' in window.navigator) && window.navigator.standalone;
const lastWebLaunch = localStorage.getItem('lastWebLaunch');
const lastWebLaunchWithinWeek = lastWebLaunch && Date.now() - lastWebLaunch < 7 * 24 * 60 * 60 * 1000;

if (isInStandaloneMode || lastWebLaunchWithinWeek) {
  launchFlutterApp();
} else {
  welcomeCt.style.display = 'block';
  if (isIos) {
    addToHomescreenCt.style.display = 'block';
  }
}

async function launchFlutterApp() {
  console.log('Launching Flutter app...');

  // remember last time web app was launched
  localStorage.setItem('lastWebLaunch', Date.now());

  // ensure all overlay content is hidden
  welcomeCt.style.display = 'none';

  // wait for app runner to be ready
  const appRunner = await flutterAppRunnerPromise;

  // run app
  console.log('Running Flutter app...');
  await appRunner.runApp();

  // remove loading indicator
  document.body.classList.remove('loading');
}
