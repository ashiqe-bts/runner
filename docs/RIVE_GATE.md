# Rive native rendering gate

The replacement renderer is **blocked**, and the working flutter_scene renderer is retained. Original rounded courier/officer meshes and their animation source are generated for both the Rive experiment and the retained renderer.

The first probe loaded with `rive 0.15.0-dev.1` but rendered no scripted geometry. Checking only Dart exceptions gave a misleading pass. A stronger test reads the registered Metal texture through a debug-only macOS channel and requires shaded pixels. A script-free control passed; the unsigned scripted scene produced one flat color. The same scripted scene renders correctly in Rive CLI 1.0.3.

The CLI's bundled `docs/publishing.md` clarifies: `--once` creates an unsigned file for the CLI or a runtime built with tools enabled. `--publish` compiles and signs scripts through Rive's service. Shipping Flutter native binaries do not include those tools. Explicit editor-VM initialization also fails because `riveVMCreate` is not exported by the shipping native library.

The earlier plan incorrectly assumed native delivery could avoid signing. This is a real dependency, not a completed renderer migration. No signature checks were removed, no account was created, and no assets were published.

To unblock: sign the completed Rive assets using an authorized Rive account, then rerun the native pixel/animation gate. CLI publishing currently adds a watermark. The existing 3D renderer remains active until the replacement passes; no flat sprites replace the 3D models.

References: https://rive.app/docs/cli/getting-started and the CLI's installed `docs/publishing.md`; https://github.com/rive-app/rive-runtime/blob/main/src/assets/script_asset.cpp .


Reproduce the native gate (currently expected to fail the shaded-pixel assertion):

```sh
./tool/flutterw test integration_test/rive_gate_test.dart -d macos \
  --dart-define=SKYWAY_VERIFY_RIVE=true
```

The default integration suite skips this experimental gate explicitly. The source and unsigned compiled demo are reviewable in `art/skyway/` and `assets/rive/skyway.riv`; a CLI rendering is retained in `docs/screenshots/rive-cli-gate.png`. Signing the demo unblocks the initial gate only. Expanding a signed Rive renderer to all game content still follows that gate.
