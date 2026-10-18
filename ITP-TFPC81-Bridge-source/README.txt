ITP-TFPC81-Bridge v1.0 (local patch, not for upload)

Makes Immersive Third Person - Best Of Both Worlds work with True First Person Camera 8.1+.
Replaces "ITP TFPC Compatibility Fix" (33471), which only supports TFPC 8.0.3.

While ITP is in third person: V's head is shown (with TPP hair/eyes appearances), TFPC's
head-hide rules are parked, TFPC (camera, lean, weapon offsets) is switched off.
Back in first person: TFPC's previous on/off and Show Head settings are restored exactly.

Requires: Codeware, Immersive Third Person, True First Person Camera 8.1+.
Without TFPC it compiles to an inert stub. If ITP changes so its third-person flag can't be
read, the bridge shows one warning and stands down - it never breaks script compilation.

Log: r6\logs\redscript_rCURRENT.log, lines starting with [ITP-TFPC Bridge].
Source: r6\scripts\ITPTFPCBridge\ITPTFPCBridge.reds
