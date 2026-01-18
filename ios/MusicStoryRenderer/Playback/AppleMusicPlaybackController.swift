import Foundation

@MainActor
final class AppleMusicPlaybackController: ObservableObject {
    @Published private(set) var queueState = PlaybackQueueState()

    func play(media: StoryMediaReference, intent: PlaybackIntent?) {
        var state = queueState
        state.play(media: media, intent: intent)
        queueState = state
    }

    func queue(media: StoryMediaReference, intent: PlaybackIntent?) {
        var state = queueState
        state.enqueue(media: media, intent: intent)
        queueState = state
    }
}
