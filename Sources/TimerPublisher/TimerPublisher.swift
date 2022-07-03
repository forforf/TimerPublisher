//
import Foundation
import Combine

public protocol CountdownPublisherArgsProtocol {
    var countdownFrom: Double { get }
    var referenceTime: TimeInterval { get }
    var interval: TimeInterval? { get }
}


@available(iOS 13.0, *)
public struct TimerPublisher {
    public static let defaultInterval = 0.5
    
    public init() {}
    
    public struct CountdownArgs: CountdownPublisherArgsProtocol {
        public let countdownFrom: Double
        public let referenceTime: TimeInterval
        public let interval: TimeInterval?
    }
    
    // Creates a publisher (correct term?) for generating intervals suitable for chaining
    // with more operators
    public func intervalPublisher(interval: TimeInterval = defaultInterval) -> AnyPublisher<TimeInterval, Never> {
        return Timer.publish(every: interval, on: .main, in: .default)
            .autoconnect()
            .map(\.timeIntervalSince1970)
            .eraseToAnyPublisher()
    }
    
    // Converts interval into elapsedTime (given a starting time `startAt`)
    // TODO: I think the name should change, I don't think it's returnin a closure anymore.
    // TODO: Should support defaultInterval
    public func elapsedPublisher(referenceTime: TimeInterval, interval: TimeInterval = defaultInterval) -> AnyPublisher<TimeInterval, Never> {
        return self.intervalPublisher(interval: interval)
            .map({ (timeInterval) in
                return timeInterval - referenceTime
            })
            .eraseToAnyPublisher()
    }
    
    // Converts an elapsedTime into a countdown timer, given `countdownFrom`
    // Note regarding Double vs TimeInterval. I don't have strong argument for using Double for Countdown it just feels
    // like the countdown is just a number to me. PS: TimeInterval is a system defined typealias for Double anyway.
    public func countdownPublisher(args: CountdownPublisherArgsProtocol) -> AnyPublisher<Double, Never> {
        let interval = args.interval ?? Self.defaultInterval
        return self.elapsedPublisher(referenceTime: args.referenceTime, interval: interval)
            .map({elapsedTime in
                return args.countdownFrom - elapsedTime
            })
            .eraseToAnyPublisher()
    }
}
