// TFPC Smooth Tick (local patch for Ethan's setup - not for upload)
//
// True First Person Camera drives its camera (lean, head look, offsets) from a DelaySystem
// callback re-armed every 16 ms. A callback can only fire on a frame, so at high frame rates
// the camera updates on roughly every 2nd-3rd frame and visibly steps, worse with frame gen.
// TFPC already measures the real time between ticks for all motion, so ticking every frame
// changes smoothness only, not speed. 0.001 s = "next frame".
//
// REQUIRES True First Person Camera (lives in its module). Disable this together with TFPC.

module TFPCSmoothTick
import TrueFirstPerson.*

@wrapMethod(IFPSystem)
private func InitSession() -> Void {
  wrappedMethod();
  this.m_tickInterval = 0.001;
}
