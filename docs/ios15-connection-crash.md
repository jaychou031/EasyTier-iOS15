# iOS 15.5 connection crash investigation

Report: EasyTier 1.2.3 build 3, iOS 15.5 (19F77), 2026-11-16 21:59:27 +0800.

The crashed process is the foreground EasyTier app. Exception: EXC_BAD_ACCESS / SIGSEGV.
The main-thread stack includes:

```
objc_msgSend
swift_getObjectType
swift_task_enqueueImpl(swift::Job*, swift::ExecutorRef)
NEVPNManager saveToPreferencesWithCompletionHandler: completion block
NEConfigurationManager saveConfiguration:withCompletionQueue:handler: completion block
```

This localizes the observed failure to asynchronous resumption after saving VPN
preferences. It does not establish a Rust core failure, a signing failure, or
which of the two save calls (installation versus connection) triggered it.

The workaround replaces SDK-imported async preference operations with explicit
completion-handler calls and checked continuations. The shared implementation
is used for installation, connection, renaming, on-demand configuration, manager
loading/removal, and widget operations. Errors continue to propagate to callers.

The macOS test harness now exercises delayed save/remove callbacks for both
success and failure using a stub manager, without changing system preferences.
These tests must run in Actions; Windows cannot compile NetworkExtension code.
They do not reproduce or certify the iOS 15.5 runtime behavior.

Device verification: install the new Actions build, retain the existing profile,
connect/disconnect repeatedly, and verify that VPN traffic works. Also test first
configuration creation on a test installation and rejected permission handling.
If the crash persists, obtain the new build's IPS report to compare stacks. This
workaround remains unconfirmed until tested on the affected device.
