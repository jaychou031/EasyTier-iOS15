const { test } = require('node:test');
const assert = require('node:assert/strict');
const { checkVersion, checkLoadCommands } = require('../ci_scripts/verify-ios15.cjs');

const build = (version, platform = '2') => `Load command 1\n cmd LC_BUILD_VERSION\n platform ${platform}\n minos ${version}\n sdk 26.2\n`;
const link = cmd => `Load command 2\n cmd ${cmd}\n name /System/Library/Frameworks/AppIntents.framework/AppIntents (offset 24)\n`;

test('accepts iOS 15.0 and earlier requirements, rejects patch/minor bumps and missing data', () => {
    for (const version of ['14.0', '15', '15.0', '15.0.0']) checkVersion(version, 'test');
    for (const version of ['15.0.1', '15.1', '16.0', '', 'unknown']) assert.throws(() => checkVersion(version, 'test'));
});
test('checks modern and legacy load commands', () => {
    checkLoadCommands(build('15.0'), 'test');
    checkLoadCommands(build('15.0', 'IOS'), 'test');
    checkLoadCommands('Load command 0\n cmd LC_VERSION_MIN_IPHONEOS\n version 15.0\n sdk 18.0', 'test');
    assert.throws(() => checkLoadCommands(build('16.0'), 'test'));
    assert.throws(() => checkLoadCommands(build('15.0', '7'), 'test'));
    assert.throws(() => checkLoadCommands('', 'test'));
});
test('checks every architecture and permits only weak AppIntents linking', () => {
    assert.throws(() => checkLoadCommands(build('15.0') + build('16.0'), 'fat binary'));
    checkLoadCommands(build('15.0') + link('LC_LOAD_WEAK_DYLIB'), 'test');
    assert.throws(() => checkLoadCommands(build('15.0') + link('LC_LOAD_DYLIB'), 'test'));
    assert.throws(() => checkLoadCommands(build('15.0') + link('LC_REEXPORT_DYLIB'), 'test'));
});
