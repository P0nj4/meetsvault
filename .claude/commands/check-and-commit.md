Run the unit tests. If they all pass, stage every changed file, commit with a descriptive message, and push to origin. If any test fails, report the failures clearly and stop — do not commit.

Steps:
1. Run `xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVaultTests -destination "platform=macOS,arch=arm64"` and capture the output.
2. Check the result:
   - If `** TEST SUCCEEDED **` appears → proceed to commit.
   - If `** TEST FAILED **` appears → print the failing test names and stop. Tell the user which tests failed and that nothing was committed.
3. On success: run `git add -A`, then commit with a short message summarising what changed (derive it from `git diff --cached --stat`), then `git push`. Report the commit hash and push result.
