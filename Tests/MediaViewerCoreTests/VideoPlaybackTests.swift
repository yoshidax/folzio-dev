import AVFoundation
import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("VideoPlayback.seekTarget")
struct VideoPlaybackSeekTargetTests {
    @Test("5 秒の動画で ±15 秒・+5 秒は [0, duration] に丸める")
    func clampsToDuration() {
        #expect(VideoPlayback.seekTarget(from: 2, by: 15, duration: 5) == 5)
        #expect(VideoPlayback.seekTarget(from: 2, by: -15, duration: 5) == 0)
        #expect(VideoPlayback.seekTarget(from: 2, by: 5, duration: 5) == 5)
        #expect(VideoPlayback.seekTarget(from: 2, by: 1.5, duration: 5) == 3.5)
    }

    @Test("位置か長さが定まらなければ nil")
    func undefined() {
        #expect(VideoPlayback.seekTarget(from: .nan, by: 5, duration: 5) == nil)
        #expect(VideoPlayback.seekTarget(from: 0, by: 5, duration: .nan) == nil)
        #expect(VideoPlayback.seekTarget(from: 0, by: 5, duration: 0) == nil)
    }
}

/// `VideoFixtures` は書き出しの間スレッドをブロックする。並列に走らせると協調スレッドを使い切って止まるため、直列にする
@Suite("VideoPlayback", .serialized)
@MainActor
struct VideoPlaybackTests {
    private func makeVideo(seconds: Double) throws -> (directory: URL, video: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoPlaybackTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let video = directory.appendingPathComponent("clip.mp4")
        try VideoFixtures.mp4(at: video, seconds: seconds)
        return (directory, video)
    }

    private func waitUntilReady(_ player: AVPlayer) async throws {
        for _ in 0..<100 where player.currentItem?.status != .readyToPlay {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(player.currentItem?.status == .readyToPlay)
    }

    /// bug: preview-skip-forward-frame-freeze。終端を越えるシークで別のアイテムへ切り替わらず、
    /// 同じアイテムの先頭から再生を続ける
    @Test("ループ再生で終端を越えてシークすると、同じアイテムの先頭から再生を続ける")
    func loopSeekPastEndKeepsItem() async throws {
        let (directory, video) = try makeVideo(seconds: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        let playback = VideoPlayback()
        playback.load(asset: AVURLAsset(url: video), loop: true)
        defer { playback.unload() }
        let player = playback.player
        let item = try #require(player.currentItem)
        try await waitUntilReady(player)

        player.play()
        try await Task.sleep(for: .milliseconds(300))
        // AVPlayerView の「15 秒進む」と同じく、丸めずに長さを越えた位置へシークする
        await player.seek(to: CMTime(seconds: 17, preferredTimescale: 600))
        try await Task.sleep(for: .milliseconds(700))

        #expect(player.currentItem === item)
        #expect(player.rate != 0)
        let current = player.currentTime().seconds
        #expect(current > 0 && current < 2)
    }

    @Test("ループ再生で先頭より前へシークしても、同じアイテムで再生を続ける")
    func loopSeekBeforeStartKeepsItem() async throws {
        let (directory, video) = try makeVideo(seconds: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        let playback = VideoPlayback()
        playback.load(asset: AVURLAsset(url: video), loop: true)
        defer { playback.unload() }
        let player = playback.player
        let item = try #require(player.currentItem)
        try await waitUntilReady(player)

        player.play()
        try await Task.sleep(for: .milliseconds(300))
        await player.seek(to: CMTime(seconds: -15, preferredTimescale: 600))
        try await Task.sleep(for: .milliseconds(500))

        #expect(player.currentItem === item)
        #expect(player.rate != 0)
        #expect(player.currentTime().seconds > 0)
    }

    @Test("ループしない再生は、終端を越えてシークすると終端で止まる")
    func noLoopStopsAtEnd() async throws {
        let (directory, video) = try makeVideo(seconds: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        let playback = VideoPlayback()
        playback.load(asset: AVURLAsset(url: video), loop: false)
        defer { playback.unload() }
        let player = playback.player
        try await waitUntilReady(player)

        player.play()
        try await Task.sleep(for: .milliseconds(300))
        await player.seek(to: CMTime(seconds: 17, preferredTimescale: 600))
        try await Task.sleep(for: .milliseconds(500))

        #expect(player.rate == 0)
        #expect(player.currentTime().seconds > 1.9)
    }

    /// bug: slideshow-video-routing-context-crash。動画を切り替えるたびに AVPlayer を作り直すと、
    /// スライドショーで routing context の生成と破棄が繰り返され、CoreMedia 内部の競合で落ちる
    @Test("動画を載せ替えても AVPlayer は同じインスタンスを使い続ける")
    func reusesPlayerAcrossLoads() async throws {
        let (directory, video) = try makeVideo(seconds: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        let playback = VideoPlayback()
        defer { playback.unload() }
        let player = playback.player

        playback.load(asset: AVURLAsset(url: video), loop: true)
        let first = try #require(player.currentItem)
        playback.unload()
        #expect(player.currentItem == nil)
        playback.load(asset: AVURLAsset(url: video), loop: false)
        let second = try #require(player.currentItem)

        #expect(playback.player === player)
        #expect(second !== first)
    }

    @Test("載せ替えたアイテムはその時のループ設定に従い、前のアイテムの終端通知で巻き戻らない")
    func reloadFollowsNewLoopSetting() async throws {
        let (directory, video) = try makeVideo(seconds: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        let playback = VideoPlayback()
        defer { playback.unload() }
        let player = playback.player

        playback.load(asset: AVURLAsset(url: video), loop: true)
        #expect(player.actionAtItemEnd == .none)
        let first = try #require(player.currentItem)

        playback.load(asset: AVURLAsset(url: video), loop: false)
        #expect(player.actionAtItemEnd == .pause)
        try await waitUntilReady(player)
        await player.seek(to: CMTime(seconds: 1, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)

        // 前のアイテムのループ監視が残っていれば、ここで新しいアイテムが先頭へ戻る
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: first)
        try await Task.sleep(for: .milliseconds(300))
        #expect(player.currentTime().seconds > 0.9)

        playback.load(asset: AVURLAsset(url: video), loop: true)
        #expect(player.actionAtItemEnd == .none)
    }

    @Test("unload で再生を止めてアイテムを外す")
    func unloadStopsAndClearsItem() async throws {
        let (directory, video) = try makeVideo(seconds: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        let playback = VideoPlayback()
        let player = playback.player
        playback.load(asset: AVURLAsset(url: video), loop: true)
        try await waitUntilReady(player)
        player.play()

        playback.unload()

        #expect(player.rate == 0)
        #expect(player.currentItem == nil)
    }
    @Test("フレーム出力はアイテムごとに1つ付き、載せ替えと unload で外れる")
    func transitionOutputLifecycle() throws {
        let (directory, video) = try makeVideo(seconds: 1)
        defer { try? FileManager.default.removeItem(at: directory) }
        let playback = VideoPlayback()
        defer { playback.unload() }
        let player = playback.player
        #expect(playback.currentFrame() == nil)
        playback.load(asset: AVURLAsset(url: video), loop: false)
        let first = try #require(player.currentItem)
        #expect(first.outputs.count == 1)
        #expect(first.outputs.first is AVPlayerItemVideoOutput)
        playback.load(asset: AVURLAsset(url: video), loop: true)
        let second = try #require(player.currentItem)
        #expect(first.outputs.isEmpty)
        #expect(second.outputs.count == 1)
        #expect(second.outputs.first is AVPlayerItemVideoOutput)
        #expect(playback.player === player)
        playback.unload()
        #expect(second.outputs.isEmpty)
        #expect(playback.currentFrame() == nil)
    }
}
