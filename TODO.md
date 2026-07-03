# TODO

## Plan for fixing terminal errors (Flutter)

1. Fix environment terminal errors:
   - Visual Studio toolchain missing: install “Desktop development with C++” workload (Visual Studio Installer)
   - Re-run `flutter doctor`
   - Then run `flutter run -d windows`

2. Collect actual terminal error output
   - Run `flutter run` from `TheyDi-main/` and capture full logs.

2. Identify the failing package/code area
   - Look for: dependency resolution, Gradle/Kotlin/Java build errors, Dart compile errors, asset/font/image issues.

3. Fix errors with minimal changes
   - Prefer pinning/removing incompatible dependency versions.
   - Prefer small code fixes only where compiler points.

4. Run `flutter clean` + dependency fetch
   - `flutter clean`
   - `flutter pub get`

5. Re-run `flutter run` and verify

6. Commit-style summary in final message

