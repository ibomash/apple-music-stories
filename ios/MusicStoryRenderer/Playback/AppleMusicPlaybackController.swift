import Foundation

protocol PlaybackControlling {
    func play(media: StoryMediaReference, intent: PlaybackIntent?)
    func queue(media: StoryMediaReference)
}

@MainActor
final class AppleMusicPlaybackController: ObservableObject, PlaybackControlling {
    func play(media: StoryMediaReference, intent: PlaybackIntent?) {
    }

    func queue(media: StoryMediaReference) {
    }
}
