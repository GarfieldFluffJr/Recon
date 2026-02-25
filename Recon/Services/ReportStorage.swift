//
//  ReportStorage.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-24.
//

// Handles saving, loading, deleting incident reports locally - simple database
// Each report gets its own .json file in a reports/ folder

import Foundation

class ReportStorageService {
    // Folder where reports are saved
    private var reportsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("reports")
        
        // Create folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    // Save a report as JSON file
    func save(report: IncidentReport) {
        let fileURL = reportsDirectory.appendingPathComponent("\(report.id.uuidString).json")
        do {
            let data = try JSONEncoder().encode(report)
            try data.write(to: fileURL)
            print("Report saved to: \(fileURL)")
        } catch {
            print("Failed to save report: \(error)")
        }
    }
    
    // Load all saved reports
    func loadAll() -> [IncidentReport] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: reportsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter {
                // $0 is first argument in closure (first parameter)
                $0.pathExtension == "json"
            }
            
            // compact map is map but skips any fails
            return jsonFiles.compactMap { fileURL in
                guard let data = try? Data(contentsOf: fileURL),
                      let report = try? JSONDecoder().decode(IncidentReport.self, from: data) else {
                    return nil
                }
                return report
            }
        } catch {
            print("Failed to load reports: \(error)")
            return []
        }
    }
    
    // Delete a report
    func delete(report: IncidentReport) {
        let fileURL = reportsDirectory.appendingPathComponent("\(report.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
}
