//
//  ProcessManager.swift
//  Chameleon
//
//  Created by Jakob Wells on 04.07.25.
//

import Foundation
import Darwin
import AppKit

final class ProcessManager {
    static let shared = ProcessManager()
    
    private var activeProcesses: Set<Process> = []
    private let queue = DispatchQueue(label: "com.chameleon.processmanager", attributes: .concurrent)
    
    private init() {
        setupTerminationHandlers()
    }
    
    func register(_ process: Process) {
        queue.async(flags: .barrier) {
            self.activeProcesses.insert(process)
            print("ProcessManager: Registered process \(process.processIdentifier)")
        }
    }
    
    func unregister(_ process: Process) {
        queue.async(flags: .barrier) {
            self.activeProcesses.remove(process)
            print("ProcessManager: Unregistered process \(process.processIdentifier)")
        }
    }
    
    func terminateAll() {
        queue.sync {
            print("ProcessManager: Terminating \(activeProcesses.count) active processes")
            
            for process in activeProcesses {
                terminateProcess(process)
            }
            
            activeProcesses.removeAll()
        }
    }
    
    private func terminateProcess(_ process: Process) {
        guard process.isRunning else { return }
        
        let processID = process.processIdentifier
        guard processID > 0 else { return }
        
        print("ProcessManager: Terminating process \(processID)")
        
        // First try SIGINT for graceful shutdown
        kill(processID, SIGINT)
        
        // Give the process a moment to clean up
        var waitCount = 0
        while process.isRunning && waitCount < 10 {
            usleep(100_000) // 100ms
            waitCount += 1
        }
        
        // Force terminate if still running
        if process.isRunning {
            print("ProcessManager: Force terminating process \(processID)")
            kill(processID, SIGTERM)
            process.waitUntilExit()
        }
    }
    
    private func setupTerminationHandlers() {
        // Handle normal app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // Handle SIGINT (Ctrl+C) and SIGTERM
        signal(SIGINT) { _ in
            ProcessManager.shared.terminateAll()
            exit(0)
        }
        
        signal(SIGTERM) { _ in
            ProcessManager.shared.terminateAll()
            exit(0)
        }
    }
    
    @objc private func appWillTerminate() {
        terminateAll()
    }
    
    deinit {
        terminateAll()
    }
}

