import { resolve, join } from "node:path";

// 只读取本地构建输入；旧 SDK 在编译前给出明确的缺失接口和平台。
const root = resolve(import.meta.dir, "..");
const project = await Bun.file(join(root, "CinePlayer.xcodeproj/project.pbxproj")).text();
const frameworks = [...new Set([...project.matchAll(/path = "?([^;"\n]+\.xcframework)"?;/g)].map(match => match[1]))];
const problems: string[] = [];
for (const name of frameworks) {
    if (!await Bun.file(join(root, "Frameworks", name, "Info.plist")).exists()) {
        problems.push(`Missing Frameworks/${name}`);
    }
}

const sdkRoot = join(root, "Frameworks/CinePlayerSDK.xcframework");
const manifest = Bun.spawn(["plutil", "-convert", "json", "-o", "-", join(sdkRoot, "Info.plist")], {
    stdout: "pipe", stderr: "pipe",
});
const manifestText = await new Response(manifest.stdout).text();
if (await manifest.exited !== 0) {
    problems.push("Cannot read CinePlayerSDK.xcframework/Info.plist");
} else {
    const info = JSON.parse(manifestText);
    const required = new Set(["ios:device", "ios:simulator", "tvos:device", "tvos:simulator", "macos:device", "xros:device", "xros:simulator"]);
    const capabilities: [string, RegExp][] = [
        ["Coordinator.shutdown", /class Coordinator[\s\S]*?func shutdown\(\)/],
        ["two-argument subtitleTranslate", /var subtitleTranslate[^\n]*\(Swift(?:\.|::)String, Swift(?:\.|::)String\)[^\n]*async throws/],
        ["throwing subtitle loading", /func loadSubtitleFile[^\n]*async throws/],
        ["subtitle translation mode", /func setSubtitleTranslationMode/],
        ["seek playback behavior", /case restorePreviousState/],
        ["frame render lookahead", /renderLookahead/],
        ["output backpressure", /func reserveOutputForNextFrame/],
        ["display geometry attachments", /enum VideoFrameAttachments/],
    ];
    for (const library of info.AvailableLibraries ?? []) {
        const platform = `${library.SupportedPlatform}:${library.SupportedPlatformVariant ?? "device"}`;
        if (!required.has(platform)) continue;
        required.delete(platform);
        const modules = join(sdkRoot, library.LibraryIdentifier, library.LibraryPath, "Modules/CinePlayerSDK.swiftmodule");
        const paths = [...new Bun.Glob("*.swiftinterface").scanSync({ cwd: modules })]
            .filter(path => !path.includes(".private.") && !path.includes(".package."));
        if (!paths.length) problems.push(`${platform}: missing public Swift interface`);
        for (const path of paths) {
            const text = await Bun.file(join(modules, path)).text();
            for (const [name, pattern] of capabilities) {
                if (!pattern.test(text)) problems.push(`${platform}/${path}: missing ${name}`);
            }
        }
        console.log(`Checked ${platform}: ${paths.length} public interface(s)`);
    }
    for (const platform of required) problems.push(`Missing SDK slice ${platform}`);
}

if (problems.length) {
    console.error(problems.join("\n"));
    process.exit(1);
}
console.log(`Frameworks verified: ${frameworks.length} bundles, all four platforms and simulator slices.`);
