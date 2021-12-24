import Foundation
import Rainbow

/**

 Groups: A, B, C, D, E, F

 Rules:
 - All A must be processed before any B
 - B1 must be processed before C1, B2 before C2, and so on
 - C1 must be processed before D1, C2 before D2, and so on
 - All D must be processed before E
 - All D must be processed before F

 */

let operations = 10
let colors = ["A": NamedColor.red, "B": .green, "C": .yellow, "D": .blue, "E": .magenta, "F": .cyan]
let groups = colors.keys.sorted()
//var progress = colors.mapValues { _ in 0 }
var progress: [String: Bool] = [:]
let lock = NSLock()


func log(_ text: String, newLine: Bool = false) {
//    lock.lock()
    fputs(text, stdout)
    if newLine {
        fputs("\n", stdout)
    }
    fflush(stdout)
//    lock.unlock()
}

func pad(_ number: Int, zeroes: Int) -> String {
    String(format: "%0\(zeroes)d", number)
}

func progressStr() -> String {
//    var total = 0
//    let parts = groups.map { group -> String in
//        let count = progress[group, default: 0]
//        total += count
//        let color = count > 0 ? colors[group, default: .default] : .default
//        return "\(group):\(pad(count, zeroes: 2))".applyingColor(color)
//    }
////    let totalColor = total > 0 ? NamedColor.lightWhite : .lightBlack
//    let totalStr = "|" + pad(total, zeroes: 3) + "|" + Array(repeating: "=", count: total).joined()
//    return "[" + parts.joined(separator: ", ") + "] \(totalStr.lightBlack)"
    var parts: [String] = []
    var total = 0
    for group in groups {
        for item in 0..<operations {
            let label = "\(group)\(pad(item, zeroes: 2))"
            let active = progress[label, default: false]
            if active {
                parts.append(label.applyingColor(colors[group, default: .lightBlack]))
                total += 1
            } else {
                parts.append(label.lightBlack)
            }
        }
    }
    let totalStr = " |" + pad(total, zeroes: 3) + "|" + Array(repeating: "=", count: total).joined()
    return parts.joined(separator: " ") + totalStr
}

func beginProcessing(group: String, itemIndex: Int) {
    let color = colors[group, default: .default]
    let label = "\(group)\(pad(itemIndex, zeroes: 2))"
    lock.lock()
//    progress[group] = progress[group, default: 0] + 1
    progress[label] = true
//    log("<\(label.applyingColor(color)) \(progressStr())", newLine: true)
    log(progressStr(), newLine: true)
    lock.unlock()
}

func endProcessing(group: String, itemIndex: Int) {
//    let color = colors[group, default: .default]
    let label = "\(group)\(pad(itemIndex, zeroes: 2))"
    lock.lock()
//    progress[group] = progress[group, default: 0] - 1
    progress[label] = false
//    log("\(label.applyingColor(color))> \(progressStr())", newLine: true)
    lock.unlock()
}

func process(group: String, itemIndex: Int) {
    beginProcessing(group: group, itemIndex: itemIndex)
    Thread.sleep(forTimeInterval: 0.1) //Double.random(in: 0.1...0.3))
    endProcessing(group: group, itemIndex: itemIndex)
}

struct Sequential {
    static func run() {
        for group in groups {
            for item in 0..<operations {
                process(group: group, itemIndex: item)
            }
        }
    }
}

struct FullyParallelized {
    static func run() {
        let groupCount = groups.count
        let total = groupCount * operations
        DispatchQueue.concurrentPerform(iterations: total) { index in
            process(group: groups[index / operations], itemIndex: index % operations)
        }
    }
}

struct Parallelized {
    static func run() {
        DispatchQueue.concurrentPerform(iterations: operations) { index in
            process(group: "A", itemIndex: index % operations)
        }
        DispatchQueue.concurrentPerform(iterations: operations) { index in
            process(group: "B", itemIndex: index % operations)
            process(group: "C", itemIndex: index % operations)
            process(group: "D", itemIndex: index % operations)
        }
        DispatchQueue.concurrentPerform(iterations: operations * 2) { index in
            process(group: groups[4 + (index / operations)], itemIndex: index % operations)
        }
    }
}

struct SingleOperationQueue {
    static func run() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = ProcessInfo.processInfo.activeProcessorCount

        let groupA = (0..<operations).map { index in
            BlockOperation {
                process(group: "A", itemIndex: index)
            }
        }
        queue.addOperations(groupA, waitUntilFinished: false)
        queue.addBarrierBlock {
            //
        }
        for number in 0..<operations {
            queue.addOperation {
                process(group: "B", itemIndex: number)
                process(group: "C", itemIndex: number)
                process(group: "D", itemIndex: number)
            }
        }
        queue.addBarrierBlock {
            //
        }
        for number in 0..<(operations*2) {
            queue.addOperation {
                process(group: groups[4 + (number / operations)], itemIndex: number % operations)
            }
        }
        queue.waitUntilAllOperationsAreFinished()
    }
}


print("ProcessorCount: ", ProcessInfo.processInfo.processorCount)
print("ActiveProcessorCount: ", ProcessInfo.processInfo.activeProcessorCount)


enum Options: String, CaseIterable {
    case sequential = "--sequential"
    case fullyParallelized = "--fully-parallel"
    case parallelized = "--parallel"
    case operationQueue = "--operation-queue"
}

let arguments = CommandLine.arguments.dropFirst()
switch Options(rawValue: arguments.first ?? "") {
case .some(.sequential):
    Sequential.run()
case .some(.fullyParallelized):
    FullyParallelized.run()
case .some(.parallelized):
    Parallelized.run()
case .some(.operationQueue):
    SingleOperationQueue.run()
default:
    let usage = """
    Usage:
      swift run scap <option>
    """
    print(usage)
    Options.allCases.forEach {
        print("    \($0.rawValue)")
    }
}
