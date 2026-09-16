{{flutter_js}}
{{flutter_build_config}}
// SoLoud 4.x exposes a factory first. Resolve its WASM before Dart initializes audio.
const audioReady = typeof Module_soloud === 'function'
  ? Module_soloud().then((module) => { window.Module_soloud = module; })
  : Promise.resolve();
audioReady.catch((error) => console.warn('Audio startup unavailable:', error))
  .finally(() => _flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}}));
