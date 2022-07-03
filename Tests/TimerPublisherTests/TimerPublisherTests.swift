import XCTest
import Combine
@testable import TimerPublisher

typealias Closure<ARG, RET> = (ARG) -> RET
typealias TimeIntervals = [TimeInterval]

@available(iOS 13.0, *)
final class TimerPublisherTests: XCTestCase {
    
    private var defaultAccuracy: Double = 0.5
    private var cancellables: Set<AnyCancellable> = []
    
    override func setUpWithError() throws {
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        cancellables = []
    }
    
    func test_initializes() throws {
        XCTAssertNotNil(TimerPublisher())
    }
    
    func test_intervalPublisher_default() throws {
        let timerPub = TimerPublisher().intervalPublisher()
        // TODO: Test values are timeIntervalsSince1970
        
        let dateRangeMin = Date().timeIntervalSince1970
        
        testIntervals(pub: timerPub, waitInterval: TimerPublisher.defaultInterval) { values in
            
            // Test Accuracy
            self.intervalAccuracy(interval: TimerPublisher.defaultInterval, accuracy: 0.3)(values)
            
            // Test Range
            let range = dateRangeMin...Date().timeIntervalSince1970
            self.intervalRange(range: range)(values)

        }
    }
    
    func test_intervalPublisher_manualInterval() throws {
        let interval = 0.3
        let timerPub = TimerPublisher().intervalPublisher(interval: interval)
        
        let dateRangeMin = Date().timeIntervalSince1970
        
        testIntervals(pub: timerPub, waitInterval: interval) { values in
            
            // Test Accuracy
            self.intervalAccuracy(interval: interval, accuracy: 0.3)(values)
            
            // Test Range
            let range = dateRangeMin...Date().timeIntervalSince1970
            self.intervalRange(range: range)(values)

        }

    }
    
    func test_elapsedPublisher_refTimeIsNow() throws {
        let refTime = Date().timeIntervalSince1970
        let interval = TimerPublisher.defaultInterval
        let timerPub = TimerPublisher().elapsedPublisher(referenceTime: refTime, interval: interval)
        
        let startInterval = Date().timeIntervalSince1970
        
        testIntervals(pub: timerPub, waitInterval: TimerPublisher.defaultInterval) { values in
            
            // Test Accuracy
            self.intervalAccuracy(interval: interval, accuracy: 0.3)(values)
            
            // Test Range
            let elapsedMax = Date().timeIntervalSince1970 - startInterval
            let range = 0...elapsedMax
            self.intervalRange(range: range)(values)
        }

    }
    
    func test_elapsedPublisher_refTimeIsPast() throws {
        let refTime = Date(timeIntervalSinceReferenceDate: 0.0).timeIntervalSince1970
        let interval = TimerPublisher.defaultInterval
        let timerPub = TimerPublisher().elapsedPublisher(referenceTime: refTime, interval: interval)
        
        let timeStart = Date().timeIntervalSince1970
        let minRange = timeStart - refTime
        testIntervals(pub: timerPub, waitInterval: TimerPublisher.defaultInterval) { values in
            
            // Test Accuracy
            self.intervalAccuracy(interval: interval, accuracy: 0.3)(values)
            
            // Test Range
            let elapsed = Date().timeIntervalSince1970 - timeStart
            let maxRange = elapsed + minRange
            let range = minRange...maxRange
            self.intervalRange(range: range)(values)
        }
    }
    
    func test_countdownPublisher_defaultInterval() throws {
        let timeStart = Date().timeIntervalSince1970
        
        let interval = TimerPublisher.defaultInterval
        // we initialize the args without an explicit interval
        let args = TimerPublisher.CountdownArgs(countdownFrom: 10.0, referenceTime: timeStart, interval: nil)
        let timerPub = TimerPublisher().countdownPublisher(args: args)
        
        testIntervals(pub: timerPub, waitInterval: interval) { values in
            
            // Test Accuracy
            self.intervalAccuracy(interval: interval, accuracy: 0.3, behavior: .descending)(values)
            self.intervalRange(range: 0...args.countdownFrom)(values)
        }
     
    }
    
    func test_countdownPublisher_maualInterval() throws {
        let timeStart = Date().timeIntervalSince1970
        
        let interval = TimerPublisher.defaultInterval
        let args = TimerPublisher.CountdownArgs(countdownFrom: 10.0, referenceTime: timeStart, interval: interval)
        let timerPub = TimerPublisher().countdownPublisher(args: args)
        
        testIntervals(pub: timerPub, waitInterval: interval) { values in
            
            // Test Accuracy
            self.intervalAccuracy(interval: interval, accuracy: 0.3, behavior: .descending)(values)
            self.intervalRange(range: 0...args.countdownFrom)(values)
        }
    }
    
    func test_countdownPublisher_continuesCountownPast0() throws {
        let timeStart = Date().timeIntervalSince1970
        
        let interval = TimerPublisher.defaultInterval
        let args = TimerPublisher.CountdownArgs(countdownFrom: 0.5, referenceTime: timeStart, interval: interval)
        let timerPub = TimerPublisher().countdownPublisher(args: args)
        
        testIntervals(pub: timerPub, waitInterval: interval) { values in
            
            // Test Accuracy
            self.intervalAccuracy(interval: interval, accuracy: 0.3, behavior: .descending)(values)
        }
    }
}

// Helpers for setting up a Subscriber to exercise the observable
@available(iOS 13.0, *)
extension TimerPublisherTests {
    typealias TimerPub = AnyPublisher<TimeInterval, Never>
    

    private func testIntervals(pub: TimerPub, waitInterval: TimeInterval, accuracy: Double? = nil, testClosure: Closure<TimeIntervals, Void>?) {
        
        let expectation = XCTestExpectation(description: "Wait for observable values")
        let numValuesToTest = 4
        let waitTime = waitInterval * Double(numValuesToTest)
        var values: TimeIntervals = []
    
        pub
            .sink { val in
                print(val)
                values.append(val)
                if values.count == numValuesToTest {
                    expectation.fulfill()
                }
                // Fail-safe
                if values.count > numValuesToTest {
                    XCTFail("Received too many values")
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 0.1 + (waitTime))
        
        XCTAssertEqual(values.count, numValuesToTest)
        
        // perform closure tests (if they exist)
        testClosure?(values)
    }
    
    
    private func testIntervalsAccuracy(pub: TimerPub, waitInterval: TimeInterval, accuracy: Double? = nil) {
        let accuracy = accuracy ?? defaultAccuracy

        testIntervals(pub: pub, waitInterval: waitInterval, accuracy: accuracy) { values in
            // Test that our intervals are at roughly the correct interval
            let valueDeltas = self.timeDelta(values)
            valueDeltas.forEach {
                XCTAssertEqual($0, waitInterval, accuracy: accuracy, "Bad Timer Interval")
            }
        }
    }
}

// Interval Calculation Helpers
@available(iOS 13.0, *)
extension TimerPublisherTests {
    
    enum IntervalBehavior {
        case ascending
        case descending
    }
    
    private func intervalAccuracy(interval: TimeInterval, accuracy: Double, behavior: IntervalBehavior = .ascending) -> Closure<TimeIntervals, Void> {
        return { values in
            // Test that our intervals are at roughly the correct interval
            let valueDeltas = self.timeDelta(values)
            valueDeltas.forEach {
                switch behavior {
                case .ascending:
                    XCTAssertEqual($0, interval, accuracy: accuracy, "Bad Timer Interval")
                case .descending:
                    XCTAssertEqual(-$0, interval, accuracy: accuracy, "Bad Timer Interval")
                }
                
            }
        }
    }
    
    private func intervalRange(range: ClosedRange<TimeInterval>) -> Closure<TimeIntervals, Void> {
        return { values in
            // Test Range
//            let dateRangeMax = Date().timeIntervalSince1970
            values.forEach { value in
                XCTAssertTrue(range.contains(value), "\(value) is not in \(range)")
            }
        }
        
    }
    
    // converts an array of size n to an array of the differences of adjacent elements (new size: n-1)
    private func timeDelta(_ ts: TimeIntervals) -> TimeIntervals {
        var deltas: TimeIntervals = []
        for i in 1...ts.count-1 {
            let delta = ts[i] - ts[i-1]
            deltas.append(delta)
        }
        return deltas
    }
}
