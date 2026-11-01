# gyro-unity-
# GyroInspector 0.1

Theos diagnostic tweak prototype for arm64/arm64e.

Features:
- Runtime log overlay.
- Checks whether UnityFramework / UnityPlayer images are loaded.
- Reads CoreMotion device rotation rate at 60 Hz.
- ON/PAUSED sampling control and sensitivity slider.

IMPORTANT: This is a diagnostic prototype, not a finished gyro fix.
The sensitivity slider currently logs its value only. It does not modify Unity camera input.
Reading CoreMotion does not make Unity consume gyro data automatically; actual camera control
requires a verified game-input integration point.

Push to GitHub, then run Actions -> Build GyroInspector. The workflow uploads build artifacts.
Compatibility with a particular LiveContainer/Tweak Loader configuration is not guaranteed.