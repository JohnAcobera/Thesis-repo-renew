# thesis_repo_renew

## Supabase configuration

Copy `.env.example` to `.env` and set `SUPABASE_URL` and
`SUPABASE_ANON_KEY` to your Supabase project URL and public anon/publishable
key. The `.env` file is ignored by Git and is not bundled as an app asset.

Pass the file to Flutter when running or building so the values are compiled
into the app. In VS Code, start the `Flutter (custom Supabase auth)` launch
configuration with F5. From a terminal, use:

```sh
flutter run --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
flutter build web --dart-define-from-file=.env --no-wasm-dry-run
```

For CI, pass values from the build environment with
`--dart-define=SUPABASE_URL="$SUPABASE_URL"` and
`--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"`, or provide a securely
managed `.env` file. The Supabase anon/publishable key is public in a web app;
never use a service-role key. Protect data with Supabase Row Level Security.
The web build command above targets the standard JavaScript output. Building
with `--wasm` also requires replacing `flutter_secure_storage` with a
WebAssembly-compatible storage implementation.

For hosting under a subpath, set the corresponding base href, for example:

```sh
flutter build web --dart-define-from-file=.env --no-wasm-dry-run --base-href=/your-subpath/
```
