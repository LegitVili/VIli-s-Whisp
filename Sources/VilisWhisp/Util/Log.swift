import Foundation
import os

enum Log {
    static let app = Logger(subsystem: "it.vili.whisp", category: "app")
    static let audio = Logger(subsystem: "it.vili.whisp", category: "audio")
    static let net = Logger(subsystem: "it.vili.whisp", category: "net")
    static let hotkey = Logger(subsystem: "it.vili.whisp", category: "hotkey")
    static let insert = Logger(subsystem: "it.vili.whisp", category: "insert")
}
