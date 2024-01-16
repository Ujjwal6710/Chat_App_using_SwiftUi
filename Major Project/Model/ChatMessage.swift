//
//  ChatMessage.swift
//  Major Project
//
//  Created by Ujjwal Chopra on 05/10/23.
//
import Foundation
import FirebaseFirestoreSwift

struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let fromId, toId, text: String
    let timestamp: Date
}
