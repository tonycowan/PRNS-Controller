# Controller package trial, 2026-09-18

Field notes from unsigned Windows and Linux packages built on `tonycowan/Prns`. Not a Ken trunk build.

## Packages

Windows `PRNS-Controller-windows-unsigned.zip` (sha256 prefix `22d4379277d24657`) is the one to ship first.

- Three files. `hopspot-flash.exe` is 7,150,592 bytes. The desktop app is 12,717,056 bytes.
- Windows 11 Pro 26200. No install step and no missing runtime.
- `hopspot-flash.exe --version` prints `0.3.7`, exits 0, and matches `HOPSPOT_FLASH_VERSION.txt`.
- The desktop app opens and drives interfaces normally.

Linux is x86-64 only. aarch64 machines cannot run these binaries.

- On Ubuntu 24.04, `hopspot-flash` runs, reports `0.3.7`, and exits 0.
- The desktop app does not start:

```
./personal-hopspot-remote-control-desktop: error while loading shared libraries:
libxdo.so.3: cannot open shared object file: No such file or directory
```

- `ldd` reports eight missing libraries, the GTK/WebKit stack the toolkit needs: `libxdo.so.3`, `libwebkit2gtk-4.1.so.0`, `libgtk-3.so.0`, `libgdk-3.so.0`, `libcairo.so.2`, `libgdk_pixbuf-2.0.so.0`, `libsoup-3.0.so.0`, `libjavascriptcoregtk-4.1.so.0`.
- An unsigned tarball does not tell the user that until the linker fails. Add a one-line note in the archive, or a launcher script that checks for them.

## Empty artifact

`inspect-windows` is the empty archive: one directory entry, no files, 206 bytes zipped. `inspect-linux` has the three unpacked files. The Windows ship zip above is not empty. Likely an upload that ran before the files existed, or a path that did not match on the Windows runner. Do not treat `inspect-windows` as the Controller package.

## USB Auto on Windows

The phone and the laptop can both look like "USB is on but has no peer" when either of these is wrong. The log already says which. The interface card does not.

1. `adb` must not hold the phone. While the adb server is running it owns the device. The open fails with Windows error 5 before accessory mode is attempted:

```
usb-auto: open aoa-start:PCIROOT(0)#...#USBROOT(0):7 failed: failed to open device (error 5)
```

Seen on the prebuilt Windows binary from this trial. `adb kill-server` clears it.

2. After the phone switches to accessory mode, the new interface needs WinUSB. Windows binds by compatible ID. On a Samsung, the vendor `dg_ssudbus` driver plus the MTP compatible ID outrank a generic driver, so the accessory interface comes up owned by something that cannot speak AOA:

```
usb-auto: open aoa:...:2:0:129:1 failed: incompatible driver is installed for this device
```

What worked: set the parent device to Microsoft `usbccgp` first, then bind WinUSB to `MI_00` with Zadig. Order matters. Binding WinUSB while the parent was still the vendor driver was undone within a second. `setupapi.dev.log` showed the WPD class installer re-binding MTP. `pnputil /restart-device` returned 50 on this machine, so it took a physical replug to settle.

Follow-ups: show that driver error in the UI. If the operator doc gets a Windows section, `adb` and the WinUSB binding are the whole of it.

## Pairing

Pairing works on both phones. `a233` paired with the Pixel over BLE, and with the S24. The interfaces list loads and can be drilled into from the phone.

Six failed attempts in a row, across three controllers and two transports, were from reading the OLED, not from the protocol. Eight hex digits in a small font on a 64x128 screen, and by the time they are typed the window is gone. Stopping the two-pass retype made the next attempt work. The window is roughly two minutes. Bigger digits on the code screen, and a remaining-time display, would help. A slow attempt and a rejected one currently look the same.

## Other

The Pixel Controller crashed twice with signal 6 (`SIGABRT`) inside `WryActivity_create`, on launch, before any interaction. It restarted fine both times.

Once, on restore after an adoption attempt, the runtime logged `persistence_restored` with `dropped=1` (`routes=1 destination_identities=1 tunnels=0 ratchets=0 refused=0`). Other restores seen in this trial had `dropped=0`. Unclear whether that record matters, or whether it is Controller or core.
