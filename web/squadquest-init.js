const flutterAppRunnerPromise = new Promise((resolve) => {
  console.log('Loading Flutter app...');
  _flutter.loader.load({
    onEntrypointLoaded: function (engineInitializer) {
      console.log('Initializing Flutter engine...');
      engineInitializer.initializeEngine().then(resolve);
    }
  });
});


// Launch app immediately
launchFlutterApp();

async function launchFlutterApp() {
  console.log('Launching Flutter app...');

  // remember last time web app was launched
  localStorage.setItem('lastWebLaunch', Date.now());

  // wait for app runner to be ready
  const appRunner = await flutterAppRunnerPromise;

  // run app
  console.log('Running Flutter app...');
  await appRunner.runApp();

  // remove loading indicator
  document.body.classList.remove('loading');
}
