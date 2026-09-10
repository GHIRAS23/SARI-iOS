#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

def read(rel: str) -> str:
    p = ROOT / rel
    if not p.is_file():
        errors.append(f"Missing required file: {rel}")
        return ""
    return p.read_text(encoding="utf-8")

def require(text: str, token: str, rel: str) -> None:
    if token not in text:
        errors.append(f"{rel}: missing safety token: {token}")

def forbid(text: str, token: str, rel: str) -> None:
    if token in text:
        errors.append(f"{rel}: forbidden release pattern remains: {token}")

engine_rel = "SARI/Sources/Core/LocalFiqhEngine.swift"
engine = read(engine_rel)
for token in (
    "maxPromptUTF8Bytes = 1_800",
    "maxQuestionUTF8Bytes = 700",
    "outputTokenLimit = 640",
    "contextSize = 3_072",
    "SamplingParams(",
    "maxTokens: Self.outputTokenLimit",
    "guard !inferenceInProgress",
    "validCitationIndexes",
    "stripSourceMarkers",
    "validateRuntime(modelURL:",
    "gpuLayers: .count(20)",
):
    require(engine, token, engine_rel)
for token in (
    "prefix(1_250)",
    "Al-Salsabil, part",
    'params: .greedy',
):
    forbid(engine, token, engine_rel)

# Prevent accidental growth above the conservative prefill safety ceiling.
m = re.search(r"maxPromptUTF8Bytes\s*=\s*([0-9_]+)", engine)
if not m:
    errors.append(f"{engine_rel}: unable to parse prompt byte ceiling")
else:
    ceiling = int(m.group(1).replace("_", ""))
    if ceiling > 1800:
        errors.append(f"{engine_rel}: prompt byte ceiling increased above validated 1800: {ceiling}")

pack_rel = "SARI/Sources/Core/LocalFiqhPack.swift"
pack = read(pack_rel)
for token in (
    'runtimeValidationVersion = "swiftllama-0.1.0-sari-safe-v2"',
    "runtime-validation.txt",
    "validateRuntimeAndMarkReady",
    "resumeBackgroundWorkIfNeeded",
    "recommendedModelSHA256",
):
    require(pack, token, pack_rel)

loader_rel = "SARI/Sources/Core/ResumableFileDownloader.swift"
loader = read(loader_rel)
for token in (
    "URLSessionConfiguration.background(",
    "sessionSendsLaunchEvents = true",
    "isDiscretionary = false",
    "backgroundSessionIdentifier",
    "task.taskDescription",
    "urlSessionDidFinishEvents(forBackgroundURLSession",
    "NSURLSessionDownloadTaskResumeData",
):
    require(loader, token, loader_rel)
forbid(loader, "URLSessionConfiguration.default", loader_rel)

app_delegate_rel = "SARI/Sources/App/SariAppDelegate.swift"
app_delegate = read(app_delegate_rel)
for token in (
    "handleEventsForBackgroundURLSession identifier",
    "setBackgroundCompletionHandler(completionHandler)",
    "prepareBackgroundSession()",
):
    require(app_delegate, token, app_delegate_rel)
# Swift 6 isolation guard retained from the previous fix.
forbid(
    app_delegate,
    "SariAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate",
    app_delegate_rel,
)

view_rel = "SARI/Sources/Features/Fiqh/FiqhAssistantView.swift"
view = read(view_rel)
for token in (
    '"النص المستند إليه"',
    "SariFiqhHistoryStore.shared",
    "didReceiveMemoryWarningNotification",
    "history.append(question: q, answer: converted)",
):
    require(view, token, view_rel)
# Source identity must remain internal and never be rendered after an answer.
for token in (
    "source.source_label",
    "open_source",
    "absoluteSourceURL",
    'Text(SariStrings.t("sources"',
    'Text("[S',
):
    forbid(view, token, view_rel)

history_rel = "SARI/Sources/Core/SariFiqhHistoryStore.swift"
history = read(history_rel)
for token in (
    "SARI/FiqhHistory/conversations.json",
    "maxConversations = 40",
    "maxTurnsPerConversation = 100",
    "func newConversation()",
):
    require(history, token, history_rel)

app_rel = "SARI/Sources/App/SARIApp.swift"
app = read(app_rel)
for token in (
    "case .background:",
    "LocalFiqhEngine.shared.releaseModelIfIdle()",
):
    require(app, token, app_rel)

workflow_rel = ".github/workflows/ios-build.yml"
workflow = read(workflow_rel)
for token in (
    "macos-15",
    "Xcode_16.4.app",
    "Xcode 16.4 is required for this release candidate",
    "python3 scripts/preflight_ios.py",
    "swiftc -parse",
    "CODE_SIGNING_ALLOWED=NO",
):
    require(workflow, token, workflow_rel)

if errors:
    print("SARI fiqh release validation FAILED:", file=sys.stderr)
    for i, error in enumerate(errors, 1):
        print(f"  {i}. {error}", file=sys.stderr)
    sys.exit(1)

print("SARI fiqh release validation OK")
print("- safe prompt/output budget locked")
print("- source identity hidden from answer UI")
print("- background model downloader wired to UIApplicationDelegate")
print("- runtime self-test marker required")
print("- local conversation history cannot inflate inference context")
