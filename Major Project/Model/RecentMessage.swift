//
//  RecentMessage.swift
//  Major Project
//
//  Created by Ujjwal Chopra on 05/10/23.
//

import Foundation
import FirebaseFirestoreSwift

struct RecentMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let text, email: String
    let fromId, toId: String
    let profileImageUrl: String
    let timestamp: Date
//    var isMarkedForDeletion: Bool = false // Add this property
    
    var username: String {
        let components = email.components(separatedBy: "@")
        
        // Get the first component (username) and capitalize its first letter
        var username = components.first?.capitalized ?? ""
        
        // Remove @gmail.com if it exists
        if components.count > 1 {
            username = username.replacingOccurrences(of: "@gmail.com", with: "")
        }
        
        return username
    }
    

    var timeAgo: String{
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate the time difference in seconds
        let timeDifference = calendar.dateComponents([.second], from: timestamp, to: now)
        
        if let seconds = timeDifference.second, seconds < 60 {
            return "just now"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        
        return formatter.localizedString(for: timestamp, relativeTo: now)
    }
}

