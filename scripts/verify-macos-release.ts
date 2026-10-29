import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const [tag, directory] = process.argv.slice(2);
if (!/^v\d+\.\d+\.\d+$/.test(tag ?? "") || !directory) {
  throw new Error("Usage: bun scripts/verify-macos-release.ts v<major>.<minor>.<patch> <artifacts-directory>");
}

function run(command: string[]): string {
  const result = Bun.spawnSync(command, { stdout: "pipe", stderr: "pipe" });
  const output = result.stdout.toString() + result.stderr.toString();
  if (result.exitCode !== 0) {
    throw new Error(`${command[0]} failed (${result.exitCode}):\n${output}`);
  }
  return output.trim();
}

const assetName = `CinePlayer-macOS-${tag}.zip`;
const archive = resolve(directory, assetName);
const checksum = (await Bun.file(`${archive}.sha256`).text()).trim().split(/\s+/);
if (checksum.length !== 2 || !/^[a-f0-9]{64}$/.test(checksum[0]) || checksum[1] !== assetName) {
  throw new Error(`Expected a SHA-256 checksum for ${assetName}`);
}
const actualHash = new Bun.CryptoHasher("sha256").update(await Bun.file(archive).arrayBuffer()).digest("hex");
if (actualHash !== checksum[0]) {
  throw new Error(`SHA-256 mismatch for ${assetName}`);
}

const temporaryDirectory = await mkdtemp(join(tmpdir(), "cineplayer-release-"));
try {
  run(["ditto", "-x", "-k", archive, temporaryDirectory]);
  const app = join(temporaryDirectory, "CinePlayer.app");
  const info = JSON.parse(run(["plutil", "-convert", "json", "-o", "-", join(app, "Contents/Info.plist")]));
  if (info.CFBundleIdentifier !== "cn.com.cinemore.cineplayer" || info.CFBundleShortVersionString !== tag.slice(1)) {
    throw new Error("App identifier or version does not match this CinePlayer release");
  }

  run(["codesign", "--verify", "--deep", "--strict", "--all-architectures", app]);
  const architectures = run(["lipo", "-archs", join(app, "Contents/MacOS/CinePlayer")]).split(/\s+/);
  for (const architecture of ["arm64", "x86_64"]) {
    if (!architectures.includes(architecture)) {
      throw new Error(`Missing ${architecture} architecture`);
    }
    const signature = run(["codesign", "--display", "--verbose=4", "--arch", architecture, app]);
    if (!signature.includes("Authority=Developer ID Application:") ||
        !signature.includes("TeamIdentifier=5AJ2RL8W58") ||
        !signature.includes("(runtime)") || !signature.includes("Timestamp=")) {
      throw new Error(`Expected timestamped Developer ID signing and Hardened Runtime for ${architecture}`);
    }
  }
  run(["xcrun", "stapler", "validate", app]);
  const assessment = run(["spctl", "--assess", "--type", "execute", "--verbose=4", app]);
  if (!assessment.includes("source=Notarized Developer ID")) {
    throw new Error(`Expected notarized Developer ID acceptance:\n${assessment}`);
  }
  console.log(`Verified ${tag} (${info.CFBundleVersion}): ${architectures.join(", ")}, Developer ID, notarized and stapled.`);
  console.log(`SHA-256: ${actualHash}`);
} finally {
  await rm(temporaryDirectory, { recursive: true });
}
