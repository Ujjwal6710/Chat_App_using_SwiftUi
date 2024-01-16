//
//  ChatUser.swift
//  Major Project
//
//  Created by Ujjwal Chopra on 16/09/23.
//

import FirebaseFirestoreSwift


struct ChatUser: Identifiable {
    
    var id: String { uid }
    
    let uid, email, profileImageUrl: String
    
    init(data: [String: Any]) {
        self.uid = data["uid"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
    }
}
