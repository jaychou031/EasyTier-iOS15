// Check the built product, not just Xcode settings. Run on the macOS runner.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

function checkVersion(value, label) {
    if (!/^\d+(\.\d+){0,2}$/.test(value)) throw Error(`${label}: invalid version ${value}`);
    const parts = value.split('.').map(Number);
    if (parts[0] > 15 || (parts[0] === 15 && parts.slice(1).some(n => n > 0))) {
        throw Error(`${label}: requires iOS ${value}, above 15.0`);
    }
}

function checkLoadCommands(output, label) {
    let versions = 0;
    for (const block of output.split(/Load command \d+/).slice(1)) {
        const cmd = block.match(/\bcmd (LC_\w+)/)?.[1];
        if (cmd === 'LC_BUILD_VERSION') {
            // otool versions print either the numeric platform or its name.
            const platform = block.match(/\bplatform (\S+)/)?.[1];
            if (!['2', 'IOS', 'iOS'].includes(platform)) throw Error(`${label}: unexpected platform ${platform}`);
            checkVersion(block.match(/\bminos (\S+)/)?.[1] ?? '', label);
            versions++;
        } else if (cmd === 'LC_VERSION_MIN_IPHONEOS') {
            checkVersion(block.match(/\bversion (\S+)/)?.[1] ?? '', label);
            versions++;
        } else if (cmd === 'LC_LOAD_DYLIB' || cmd === 'LC_REEXPORT_DYLIB') {
            // These frameworks do not exist on iOS 15. They must be weak-linked.
            if (/\/(AppIntents|SwiftUICore)\.framework\//.test(block)) {
                throw Error(`${label}: strong link to a framework unavailable on iOS 15`);
            }
        }
    }
    if (!versions) throw Error(`${label}: missing iOS minimum-version load command`);
}

function verify(appPath) {
    if (!appPath || !fs.statSync(appPath).isDirectory()) throw Error('Pass the archived EasyTier.app directory');
    for (const required of ['Info.plist', 'PlugIns/EasyTierNetworkExtension.appex/Info.plist', 'PlugIns/EasyTierWidgetExtension.appex/Info.plist']) {
        if (!fs.existsSync(path.join(appPath, required))) throw Error(`Missing ${required}`);
    }
    let bundles = 0;
    let binaries = 0;
    function visit(dir) {
        if (/\.(app|appex|framework)$/.test(dir)) {
            const plist = path.join(dir, 'Info.plist');
            const info = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', plist], { encoding: 'utf8' }));
            checkVersion(info.MinimumOSVersion ?? '', plist);
            if ((dir.endsWith('.app') || dir.endsWith('.appex')) && info.MinimumOSVersion !== '15.0') {
                throw Error(`${plist}: expected MinimumOSVersion 15.0`);
            }
            if (!info.CFBundleExecutable || !fs.existsSync(path.join(dir, info.CFBundleExecutable))) throw Error(`${dir}: missing executable`);
            bundles++;
        }
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            const file = path.join(dir, entry.name);
            if (entry.isSymbolicLink()) continue;
            if (entry.isDirectory()) { visit(file); continue; }
            const fd = fs.openSync(file, 'r');
            const magic = Buffer.alloc(4);
            try { fs.readSync(fd, magic, 0, 4, 0); } finally { fs.closeSync(fd); }
            if (!['cffaedfe', 'cefaedfe', 'feedfacf', 'feedface', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca'].includes(magic.toString('hex'))) continue;
            const output = execFileSync('xcrun', ['otool', '-l', file], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
            checkLoadCommands(output, file);
            console.log(`iOS 15 compatible load commands: ${path.relative(appPath, file)}`);
            binaries++;
        }
    }
    visit(appPath);
    if (bundles < 3 || binaries < 3) throw Error('Incomplete app or extensions');
    console.log(`Verified ${bundles} bundles and ${binaries} Mach-O binaries. Device testing is still required.`);
}

module.exports = { checkVersion, checkLoadCommands };
if (require.main === module) verify(process.argv[2]);
