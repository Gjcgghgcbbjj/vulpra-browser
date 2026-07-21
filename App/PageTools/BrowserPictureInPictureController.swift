import AVFoundation
import AVKit
import GeckoView

final class BrowserPictureInPictureController: NSObject, PictureInPictureDelegate,
    AVPictureInPictureSampleBufferPlaybackDelegate {
    private weak var session: GeckoSession?
    private var controller: AVPictureInPictureController?
    private var playing = true

    func attach(to session: GeckoSession) {
        self.session = session
        session.pictureInPictureDelegate = self
    }

    func start() {
        guard AVPictureInPictureController.isPictureInPictureSupported(), let session,
              let candidate = session.pictureInPictureCandidates.max(by: { $0.enqueueCount < $1.enqueueCount }) else { return }
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: candidate.displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        self.controller = controller
        controller.startPictureInPicture()
    }

    func onLayerChanged(session: GeckoSession) {
        if controller?.isPictureInPictureActive == true { return }
        self.session = session
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    setPlaying playing: Bool) {
        self.playing = playing
        playing ? session?.mediaSession.play() : session?.mediaSession.pause()
    }

    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool { !playing }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completionHandler: @escaping () -> Void) {
        let seconds = CMTimeGetSeconds(skipInterval)
        if seconds >= 0 { session?.mediaSession.seekForward(offset: seconds) }
        else { session?.mediaSession.seekBackward(offset: abs(seconds)) }
        completionHandler()
    }
}
