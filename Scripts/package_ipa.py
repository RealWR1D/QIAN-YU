"""Package a device build with readable entitlements for SideStore to re-sign."""
import argparse
import datetime
import hashlib
import json
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
IPA_NAME = "QIAN-YU-iOS-SideStore.ipa"
CHANNEL = "ios-sideload"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def load_plist(path):
    with path.open("rb") as file:
        return plistlib.load(file)


def package(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="qianyu-ipa-") as temp:
        payload = pathlib.Path(temp) / "Payload"
        app = payload / "QIAN YU.app"
        shutil.copytree(args.app, app, symlinks=True)
        extensions = sorted((app / "PlugIns").glob("*.appex"))
        if len(extensions) != 1:
            raise ValueError("Expected the QianYuWidgets extension for Live Activities")
        bundles = [*extensions, app]
        app_info = load_plist(app / "Info.plist")
        if app_info["CFBundleIdentifier"] != "com.qianyu.companion":
            raise ValueError("Unexpected main bundle identifier")
        permissions = set()
        privacy = {}
        version = app_info["CFBundleShortVersionString"]
        for bundle in bundles:
            path = bundle / "Info.plist"
            info = load_plist(path)
            if "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", []):
                raise ValueError(f"Not a physical-device build: {bundle.name}")
            if not (bundle / "Assets.car").is_file():
                raise ValueError(f"Missing compiled avatars/icons: {bundle.name}")
            executable = bundle / info["CFBundleExecutable"]
            run("lipo", str(executable), "-verify_arch", "arm64")
            if "cryptid 1" in run("otool", "-l", str(executable)):
                raise ValueError("Encrypted apps cannot be re-signed")
            info["CFBundleShortVersionString"] = version
            info["CFBundleVersion"] = args.build_version
            info["QianYuSourceCommit"] = args.commit
            with path.open("wb") as file:
                plistlib.dump(info, file)
            privacy.update({key: value for key, value in info.items() if key.startswith("NS") and key.endswith("UsageDescription")})
            entitlement_path = ROOT / ("QIAN_YU/QIAN_YU.entitlements" if bundle == app else "QIAN_YU/Widgets/QianYuWidgets.entitlements")
            permissions.update(load_plist(entitlement_path))
            # Frameworks and dylibs must be sealed before their enclosing bundle.
            nested = [path for path in (bundle / "Frameworks").rglob("*") if path.suffix in (".framework", ".dylib")]
            for path in sorted(nested, key=lambda path: len(path.parts), reverse=True):
                run("codesign", "--force", "--sign", "-", "--timestamp=none", str(path))
            run("codesign", "--force", "--sign", "-", "--timestamp=none", "--entitlements", str(entitlement_path), str(bundle))
        run("codesign", "--verify", "--deep", "--strict", str(app))
        ipa = output / IPA_NAME
        with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(payload.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(pathlib.Path(temp)))
        with zipfile.ZipFile(ipa) as archive:
            if archive.testzip() is not None:
                raise ValueError("Corrupt IPA archive")
            for bundle in bundles:
                info_path = (bundle / "Info.plist").relative_to(pathlib.Path(temp)).as_posix()
                if plistlib.loads(archive.read(info_path))["CFBundleVersion"] != args.build_version:
                    raise ValueError("Version mismatch in IPA")
        base = f"https://github.com/{args.repository}/releases/download/{CHANNEL}"
        icon = f"https://raw.githubusercontent.com/{args.repository}/main/QIAN_YU/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024x1024_ios.png"
        source = {
            "name": "QIAN YU", "identifier": "com.qianyu.sidestore-source",
            "subtitle": "千语陪伴、课程表与专注计时", "iconURL": icon,
            "website": f"https://github.com/{args.repository}",
            "sourceURL": f"{base}/sidestore.json", "tintColor": "FF8800",
            "apps": [{
                "name": "QIAN YU", "bundleIdentifier": app_info["CFBundleIdentifier"],
                "developerName": "RealWR1D", "iconURL": icon,
                "localizedDescription": "千语陪伴、ICS 课表导入、聊天、每日提醒与专注计时。通过自己的免费 Apple 账号签名，每 7 天续签。包含小组件与灵动岛扩展，设备兼容性需要安装后验证。",
                "versions": [{
                    "version": version, "buildVersion": args.build_version,
                    "date": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    "localizedDescription": f"源码提交 {args.commit[:7]}；包含最新聊天与性能修复。",
                    "downloadURL": f"{base}/{IPA_NAME}", "size": ipa.stat().st_size,
                    "minOSVersion": app_info["MinimumOSVersion"],
                }],
                "appPermissions": {"entitlements": sorted(permissions), "privacy": privacy},
            }], "news": [],
        }
        (output / "sidestore.json").write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        (output / "build-info.json").write_text(json.dumps({"commit": args.commit, "version": version, "buildVersion": args.build_version, "signing": "ad hoc; re-sign with a personal Apple account before installation"}, indent=2) + "\n")
        files = [IPA_NAME, "sidestore.json", "build-info.json"]
        (output / "SHA256SUMS-ios.txt").write_text("".join(f"{hashlib.sha256((output / name).read_bytes()).hexdigest()}  {name}\n" for name in files))
        print(f"IPA verified: {ipa} ({ipa.stat().st_size:,} bytes), version {version} ({args.build_version}), widget included")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--build-version", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--repository", default="RealWR1D/QIAN-YU")
    arguments = parser.parse_args()
    if not arguments.build_version.isdigit() or not 0 < int(arguments.build_version) < 100000:
        parser.error("build-version must be a positive integer below 100000")
    package(arguments)
