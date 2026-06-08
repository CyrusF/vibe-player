import AppKit
import Foundation

public enum VideoControlAction: String, Codable, Sendable {
    case play
    case pause
    case status
}

public struct VideoControlResult: Codable, Equatable, Sendable {
    public var ok: Bool
    public var action: String?
    public var changed: Bool
    public var reason: String?
    public var wasPaused: Bool?
    public var isPaused: Bool?
    public var readyState: Int?

    public init(
        ok: Bool,
        action: String? = nil,
        changed: Bool = false,
        reason: String? = nil,
        wasPaused: Bool? = nil,
        isPaused: Bool? = nil,
        readyState: Int? = nil
    ) {
        self.ok = ok
        self.action = action
        self.changed = changed
        self.reason = reason
        self.wasPaused = wasPaused
        self.isPaused = isPaused
        self.readyState = readyState
    }
}

public enum PlayerControlError: LocalizedError, Equatable {
    case browserNotRunning(String)
    case noTarget(String)
    case scriptFailed(String)
    case badResponse(String)

    public var errorDescription: String? {
        switch self {
        case .browserNotRunning(let name):
            return "\(name) is not running."
        case .noTarget(let message):
            return message
        case .scriptFailed(let message):
            return message
        case .badResponse(let message):
            return "Unexpected browser response: \(message)"
        }
    }
}

public protocol PlayerControlling {
    func captureActiveTarget(in browser: BrowserKind) -> Result<PlayerTarget, PlayerControlError>
    func control(_ action: VideoControlAction, target: PlayerTarget) -> Result<VideoControlResult, PlayerControlError>
}

public final class BrowserVideoController: PlayerControlling {
    private let decoder = JSONDecoder()

    public init() {}

    public func captureActiveTarget(in browser: BrowserKind) -> Result<PlayerTarget, PlayerControlError> {
        guard isBrowserRunning(browser) else {
            return .failure(.browserNotRunning(browser.displayName))
        }

        let script = browser.isSafari
            ? safariCaptureScript(browser: browser)
            : chromiumCaptureScript(browser: browser)

        switch runAppleScript(script) {
        case .failure(let error):
            return .failure(error)
        case .success(let value):
            let parts = value.components(separatedBy: "\t")
            guard parts.count >= 4 else {
                return .failure(.badResponse(value))
            }
            if parts[0] == "ERROR" {
                return .failure(.noTarget(parts.dropFirst().joined(separator: " ")))
            }
            guard let windowIndex = Int(parts[0]), let tabIndex = Int(parts[1]) else {
                return .failure(.badResponse(value))
            }
            return .success(PlayerTarget(
                browser: browser,
                windowIndex: windowIndex,
                tabIndex: tabIndex,
                title: parts[2],
                url: parts.dropFirst(3).joined(separator: "\t")
            ))
        }
    }

    public func control(_ action: VideoControlAction, target: PlayerTarget) -> Result<VideoControlResult, PlayerControlError> {
        guard isBrowserRunning(target.browser) else {
            return .failure(.browserNotRunning(target.browser.displayName))
        }

        let js = Self.videoControlJavaScript(action: action)
        let script = target.browser.isSafari
            ? safariControlScript(target: target, javaScript: js)
            : chromiumControlScript(target: target, javaScript: js)

        switch runAppleScript(script) {
        case .failure(let error):
            return .failure(error)
        case .success(let response):
            guard let data = response.data(using: .utf8) else {
                return .failure(.badResponse(response))
            }
            do {
                return .success(try decoder.decode(VideoControlResult.self, from: data))
            } catch {
                return .failure(.badResponse(response))
            }
        }
    }

    static func videoControlJavaScript(action: VideoControlAction) -> String {
        """
        (() => {
          const action = "\(action.rawValue)";
          const visible = (element) => {
            if (!element) return false;
            const rect = element.getBoundingClientRect();
            const style = window.getComputedStyle(element);
            return rect.width > 0 &&
              rect.height > 0 &&
              style.display !== "none" &&
              style.visibility !== "hidden" &&
              style.opacity !== "0";
          };
          const videos = Array.from(document.querySelectorAll("video")).filter((video) => {
            const rect = video.getBoundingClientRect();
            return rect.width >= 160 &&
              rect.height >= 90 &&
              !video.ended &&
              visible(video);
          });
          if (!videos.length) {
            return JSON.stringify({ ok: false, changed: false, reason: "no-visible-video" });
          }
          videos.sort((a, b) => {
            const ar = a.getBoundingClientRect();
            const br = b.getBoundingClientRect();
            return (br.width * br.height) - (ar.width * ar.height);
          });
          const video = videos[0];
          const wasPaused = video.paused;
          const payload = (values) => JSON.stringify(Object.assign({
            ok: true,
            action,
            changed: false,
            wasPaused,
            isPaused: video.paused,
            readyState: video.readyState
          }, values || {}));
          const clickFirstVisible = (selectors) => {
            for (const selector of selectors) {
              for (const element of Array.from(document.querySelectorAll(selector))) {
                if (visible(element)) {
                  element.click();
                  return selector;
                }
              }
            }
            return null;
          };
          const requestPlay = () => {
            try {
              const maybePromise = video.play();
              if (maybePromise && typeof maybePromise.catch === "function") {
                maybePromise.catch(() => {});
              }
              return null;
            } catch (error) {
              return error && error.message ? error.message : String(error);
            }
          };
          if (action === "status") {
            return payload({ reason: video.paused ? "paused" : "playing" });
          }
          if (action === "pause") {
            if (!video.paused) {
              video.pause();
              return payload({ changed: true, isPaused: video.paused, reason: "paused" });
            }
            return payload({ reason: "already-paused" });
          }
          if (action === "play") {
            if (video.paused) {
              const nativeError = requestPlay();
              let clickedSelector = null;
              if (video.paused) {
                clickedSelector = clickFirstVisible([
                  ".ytp-play-button",
                  ".bpx-player-ctrl-play",
                  ".vjs-play-control",
                  ".plyr__control[data-plyr='play']",
                  "button[aria-label='Play']",
                  "button[aria-label='播放']",
                  "button[title='Play']",
                  "button[title='播放']",
                  "[data-testid*='play']"
                ]);
              }
              return payload({
                changed: wasPaused && !video.paused,
                reason: video.paused ? "play-requested-still-paused" : "playing",
                clickedSelector,
                nativeError
              });
            }
            return payload({ reason: "already-playing" });
          }
          return JSON.stringify({ ok: false, changed: false, reason: "unknown-action" });
        })();
        """
    }

    private func isBrowserRunning(_ browser: BrowserKind) -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.localizedName == browser.displayName || app.bundleIdentifier?.localizedCaseInsensitiveContains(browser.rawValue) == true
        }
    }

    private func chromiumCaptureScript(browser: BrowserKind) -> String {
        """
        tell application "\(browser.appleScriptName)"
          if not (exists front window) then return "ERROR\tNo browser window"
          set wIndex to index of front window
          set tIndex to active tab index of front window
          set theTitle to title of active tab of front window
          set theURL to URL of active tab of front window
          return (wIndex as text) & "\t" & (tIndex as text) & "\t" & theTitle & "\t" & theURL
        end tell
        """
    }

    private func safariCaptureScript(browser: BrowserKind) -> String {
        """
        tell application "\(browser.appleScriptName)"
          if not (exists front window) then return "ERROR\tNo browser window"
          set wIndex to index of front window
          set theTab to current tab of front window
          set tIndex to index of theTab
          set theTitle to name of theTab
          set theURL to URL of theTab
          return (wIndex as text) & "\t" & (tIndex as text) & "\t" & theTitle & "\t" & theURL
        end tell
        """
    }

    private func chromiumControlScript(target: PlayerTarget, javaScript: String) -> String {
        """
        tell application "\(target.browser.appleScriptName)"
          tell window \(target.windowIndex)
            tell tab \(target.tabIndex)
              execute javascript "\(Self.escapeAppleScript(javaScript))"
            end tell
          end tell
        end tell
        """
    }

    private func safariControlScript(target: PlayerTarget, javaScript: String) -> String {
        """
        tell application "\(target.browser.appleScriptName)"
          do JavaScript "\(Self.escapeAppleScript(javaScript))" in tab \(target.tabIndex) of window \(target.windowIndex)
        end tell
        """
    }

    private func runAppleScript(_ source: String) -> Result<String, PlayerControlError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.scriptFailed("Could not create AppleScript."))
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = (errorInfo[NSAppleScript.errorMessage] as? String)
                ?? errorInfo.description
            return .failure(.scriptFailed(message))
        }
        return .success(result.stringValue ?? "")
    }

    static func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
