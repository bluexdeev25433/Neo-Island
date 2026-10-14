import pathlib
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class ProjectStructureTests(unittest.TestCase):
    def test_plists_parse_and_filter_only_springboard(self):
        tweak = plistlib.loads((ROOT / "NeoIsland.plist").read_bytes())
        prefs = plistlib.loads((ROOT / "Preferences/Info.plist").read_bytes())
        entry = plistlib.loads((ROOT / "layout/Library/PreferenceLoader/Preferences/com.neoisland.preferences.plist").read_bytes())
        self.assertEqual(tweak["Filter"]["Bundles"], ["com.apple.springboard"])
        self.assertEqual(prefs["CFBundleIdentifier"], "com.neoisland.preferences")
        self.assertEqual(entry["entry"]["bundle"], "NeoIslandPrefs")
        self.assertEqual(entry["entry"]["detail"], "NISettingsController")

    def test_release_version_matches_package_and_preferences(self):
        control = (ROOT / "control").read_text()
        prefs = plistlib.loads((ROOT / "Preferences/Info.plist").read_bytes())
        readme = (ROOT / "README.md").read_text()
        self.assertRegex(control, r"(?m)^Version: 1\.1\.0$")
        self.assertEqual(prefs["CFBundleVersion"], "1.1.0")
        self.assertEqual(prefs["CFBundleShortVersionString"], "1.1.0")
        self.assertIn("**1.1.0**", readme)

    def test_ci_pins_the_available_ios_sdk_and_uploads_logs_on_failure(self):
        workflow = (ROOT / ".github/workflows/build.yml").read_text()
        self.assertIn('install-sdk" iPhoneOS16.5', workflow)
        self.assertIn("if: always()", workflow)
        self.assertIn("if: success()", workflow)

    def test_release_workflow_builds_packages_and_generates_verified_apt_repo(self):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertIn('tags: ["v1.1.0"]', workflow)
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("dpkg-scanpackages", workflow)
        self.assertIn("apt-ftparchive release", workflow)
        self.assertIn("SHA256SUMS", workflow)
        self.assertIn("actions/upload-pages-artifact", workflow)
        self.assertIn("actions/deploy-pages", workflow)
        self.assertLess(workflow.index("actions/deploy-pages@v4"), workflow.index("gh release create"))
        self.assertIn('git archive --format=zip --prefix=NeoIsland-${VERSION}/ "v${VERSION}"', workflow)

    def test_website_hides_sileo_link_until_repository_indexes_validate(self):
        website = (ROOT / "docs/index.html").read_text()
        self.assertIn('id="sileo-button"', website)
        self.assertIn('id="sileo-button" href="#" hidden', website)
        self.assertIn('crypto.subtle.digest("SHA-256"', website)
        self.assertIn("verifyIndex(\"iphoneos-arm\", releaseText)", website)
        self.assertIn("verifyIndex(\"iphoneos-arm64\", releaseText)", website)

    def test_makefiles_reference_existing_sources(self):
        root_make = (ROOT / "Makefile").read_text()
        pref_make = (ROOT / "Preferences/Makefile").read_text()
        source_line = re.search(r"^NeoIsland_FILES\s*:=\s*(.*)$", root_make, re.MULTILINE)
        self.assertIsNotNone(source_line)
        for source in source_line.group(1).split():
            self.assertTrue((ROOT / source).is_file(), source)
        self.assertIn("NISettingsController.m", pref_make)
        self.assertTrue((ROOT / "Preferences/NISettingsController.m").is_file())

    def test_preference_keys_are_declared_in_schema(self):
        settings = (ROOT / "Preferences/NISettingsController.m").read_text()
        configuration = (ROOT / "Sources/NIConfigurationManager.m").read_text()
        setting_keys = set(re.findall(r'key:@"([A-Za-z][A-Za-z0-9]+)"', settings))
        schema_keys = set(re.findall(r'@"([A-Za-z][A-Za-z0-9]+)"\s*:', configuration))
        self.assertTrue(setting_keys)
        self.assertLessEqual(setting_keys, schema_keys)

    def test_preferences_guard_invalid_keys_and_unavailable_defaults(self):
        settings = (ROOT / "Preferences/NISettingsController.m").read_text()
        self.assertIn('if (![key isKindOfClass:NSString.class] || key.length == 0) return nil;', settings)
        self.assertIn('|| !self.settings) return;', settings)
        self.assertIn('command < 1 || command > 4', settings)

    def test_epoch_timestamp_is_not_clamped_to_slider_ranges(self):
        source = (ROOT / "Sources/NIConfigurationManager.m").read_text()
        self.assertIn('@"TimerEndTimestamp"', source)
        self.assertIn("4102444800.0", source)

    def test_timer_tick_finishes_at_expiry_and_disposal_is_nonretaining(self):
        source = (ROOT / "Sources/NIModuleProvider.m").read_text()
        tick = source.split("- (void)timerDidTick:", 1)[1].split("- (void)toggleMusic", 1)[0]
        ticker = source.split("- (void)startTicker", 1)[1].split("- (void)timerDidTick:", 1)[0]
        finish = source.split("- (void)finishTimer", 1)[1].split("- (void)startTicker", 1)[0]
        self.assertIn("NITimerLogicIsExpired", tick)
        self.assertIn("[self finishTimer]", tick)
        self.assertIn("__weak typeof(self) weakSelf", ticker)
        self.assertIn("if (self.timerTicker) return", ticker)
        self.assertIn("strongSelf.timerTicker != timer", ticker)
        self.assertIn("[self.timerTicker invalidate]", finish)

    def test_disabling_timer_cancels_running_and_paused_state(self):
        source = (ROOT / "Sources/NIModuleProvider.m").read_text()
        handler = source.split("- (void)handleConfigurationChanges", 1)[1].split("- (void)updateObserversForConfiguration", 1)[0]
        self.assertIn("if (!timerEnabled)", handler)
        self.assertIn("state.pausedRemaining > 0", handler)
        self.assertIn("[self finishTimer]", handler)

    def test_timer_state_boundary_regression_binary(self):
        with tempfile.TemporaryDirectory(prefix="neo-island-test-") as temp_dir:
            binary = pathlib.Path(temp_dir) / "timer-state-test"
            subprocess.run(
                ["clang", "-std=c11", "-Wall", "-Wextra", "-Werror", "-ISources",
                 "tests/timer_state_test.c", "-lm", "-o", str(binary)],
                cwd=ROOT,
                check=True,
            )
            subprocess.run([str(binary)], cwd=ROOT, check=True)

    def test_island_mode_transitions_binary(self):
        with tempfile.TemporaryDirectory(prefix="neo-island-mode-test-") as temp_dir:
            binary = pathlib.Path(temp_dir) / "island-mode-test"
            subprocess.run(
                ["clang", "-std=c11", "-Wall", "-Wextra", "-Werror", "-ISources",
                 "tests/island_mode_test.c", "-o", str(binary)],
                cwd=ROOT,
                check=True,
            )
            subprocess.run([str(binary)], cwd=ROOT, check=True)

    def test_renderer_delegates_selection_and_state_to_manager(self):
        renderer = (ROOT / "Sources/NIIslandView.m").read_text()
        state = (ROOT / "Sources/NIIslandStateManager.m").read_text()
        self.assertIn("NIIslandStateManager *stateManager", renderer)
        self.assertIn("[self.stateManager moveSelection:direction]", renderer)
        self.assertIn("selectedSnapshotIdentifier", state)
        self.assertIn("containsObject:self.selectedSnapshotIdentifier", state)
        self.assertNotIn("currentIndex", renderer)

    def test_renderer_relayouts_to_current_screen_and_safe_area(self):
        renderer = (ROOT / "Sources/NIIslandView.m").read_text()
        self.assertIn("self.window.frame = UIScreen.mainScreen.bounds", renderer)
        self.assertIn("self.window.safeAreaInsets", renderer)
        self.assertIn("UIAccessibilityIsReduceMotionEnabled()", renderer)

    def test_unknown_models_fail_closed_and_native_models_are_excluded(self):
        source = (ROOT / "Sources/NICompatibility.m").read_text()
        self.assertIn("nativeIslandModels", source)
        self.assertIn("legacyOverlayModels", source)
        self.assertIn("return [legacyOverlayModels containsObject:self.machineIdentifier]", source)

    def test_volume_changes_refresh_snapshots_and_observer_is_removed(self):
        source = (ROOT / "Sources/NIModuleProvider.m").read_text()
        self.assertIn('addObserver:self forKeyPath:@"outputVolume"', source)
        self.assertIn('removeObserver:self forKeyPath:@"outputVolume"', source)
        self.assertIn('context == NIAudioVolumeContext', source)
        self.assertIn("dispatch_async(dispatch_get_main_queue(), ^{ [self refreshAndNotify]; });", source)

    def test_provider_reconciles_timer_on_wake_and_recognizes_external_routes(self):
        source = (ROOT / "Sources/NIModuleProvider.m").read_text()
        self.assertIn("UIApplicationDidBecomeActiveNotification", source)
        self.assertIn("UIApplicationSignificantTimeChangeNotification", source)
        self.assertIn("NITimerLogicIsExpired(state, NSDate.date.timeIntervalSince1970)", source)
        self.assertIn("AVAudioSessionPortAirPlay", source)
        self.assertIn("AVAudioSessionPortCarAudio", source)

    def test_sources_have_no_placeholder_markers(self):
        source_files = list((ROOT / "Sources").glob("*.m")) + list((ROOT / "Sources").glob("*.h"))
        combined = "\n".join(path.read_text() for path in source_files)
        self.assertIsNone(re.search(r"\b(TODO|FIXME|PLACEHOLDER|PSEUDOCODE)\b", combined, re.IGNORECASE))


if __name__ == "__main__":
    unittest.main()