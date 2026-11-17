# Transfer Validation

The Android app now uses protocol version 2. Install the updated app on both
devices; protocol 1 peers are intentionally rejected.

## Transfer Behavior

- AES-256-GCM encrypted 28 KiB chunks, with a 32 KiB packet size guard.
- At most 128 unacknowledged chunks (about 3.5 MiB of file data) in flight.
- Receiver storage readiness is negotiated before sending file data.
- Every 64 contiguous chunks, the receiver flushes data and saves a resume
  checkpoint before acknowledging it.
- The receiver hashes the saved file in a separate isolate. The sender only
  reports completion after an authenticated verification response.
- Existing destination files are preserved with numbered filename suffixes.
- One stream subscription handles all files in a connection.
- Control messages use HMAC-SHA256 with the QR session key.
- Android foreground service and a partial wake lock protect active sessions.
- Resume from History, then scan the receiver's new QR code. The original
  source file and the receiver's partial file/checkpoint must still exist.

## Automated Coverage

`flutter test --no-pub` runs the existing tests and transport regression tests.
The transport suite exercises real files, encryption, hashing and checkpoints
over an in-memory link. It covers a 5 MiB file spanning multiple ACK windows,
consecutive and empty files, filename collisions, interrupted transfer resume,
corrupt/missing/duplicate chunks, modified control messages, missing final
verification, pause/resume, ACK timeout, and cancelling an idle receiver.

This does not measure Nearby radio throughput or emulate Android process death.

## Device Validation

Use release builds for throughput measurements.

1. Transfer a 1 GiB or larger file and compare its SHA-256 on both devices.
2. Transfer several files together, including empty files and repeated names.
3. Pause on either device, wait, then resume.
4. Disconnect after several checkpoints. Reconnect via History and a fresh QR;
   confirm progress starts from the receiver's durable checkpoint.
5. Turn off the screen during transfer and check the ongoing notification.
6. Try a third advertising receiver nearby; the sender must select only the
   scanned QR session.

Actual speed and background behavior still depend on device hardware, storage,
Android/OEM battery policies and the Nearby link. No measured phone-to-phone
speed increase or successful gigabyte transfer is claimed by the unit tests.
