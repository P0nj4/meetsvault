Run the unit tests, fix any failing tests, then commit the changes with a descriptive message and push to origin.

Steps:

1. Run `xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVaultTests -destination "platform=macOS,arch=arm64"` and capture the output.

2. If the run ends in `** TEST FAILED **`:
   - Identify each failing test from the output (file, test method, assertion).
   - For every failure, decide whether the test or the production code is wrong:
     - If the test's expectation no longer matches intended behaviour → update the test.
     - If the test is correct and the production code regressed → stop and report; do not "fix" by weakening the assertion.
   - Apply the fixes, then re-run the same `xcodebuild test` command.
   - Repeat until the run ends in `** TEST SUCCEEDED **`. If after one fix attempt the same test still fails for the same reason, stop and report — do not loop blindly.

3. Run `/security-review` on the pending changes. If any high or critical findings are reported, stop and present them to the user — do not commit until they are addressed or explicitly dismissed.

4. Once tests pass and the security review is clean (or findings are acknowledged), build the commit:
   - Run `git status` and `git diff` (staged + unstaged) to see every change, including any test fixes you just made.
   - Skip files that look like secrets (`.env`, credentials, keychains).
   - Stage the relevant files explicitly with `git add <paths>` (avoid `git add -A` so stray artefacts don't sneak in).
   - Derive a concise commit message (1–2 sentences) from the actual diff — focus on the "why", not a file list. If tests were updated, mention it briefly (e.g. "…and update FilenameBuilderTests for new format").
   - Follow the repo's existing commit style (check `git log -5 --oneline`).

5. Commit with a HEREDOC so multi-line formatting survives:

   ```
   git commit -m "$(cat <<'EOF'
   <message>

   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
   EOF
   )"
   ```

6. Push: `git push`. If the branch has no upstream, use `git push -u origin HEAD`.

7. Report: the commit hash, the one-line message, and the push result. If any tests were modified to fix failures, list them so the user can sanity-check.

Guardrails:
- Never use `--no-verify`, `--amend`, or force-push.
- Never commit if tests are still failing.
- If you cannot determine whether a failing test should be updated or the production code should be fixed, stop and ask.
