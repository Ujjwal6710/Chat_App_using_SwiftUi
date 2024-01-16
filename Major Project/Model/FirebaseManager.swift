//
//  FirebaseManager.swift
//  Major Project
//
//  Created by Ujjwal Chopra on 08/10/23.
//

import Foundation
import FirebaseStorage
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

class FirebaseManager: NSObject {
    
    let auth: Auth
    let storage: Storage
    let firestore: Firestore
    
    var currentUser: ChatUser?
    
    static let shared = FirebaseManager()
    
    override init() {
        FirebaseApp.configure()
        
        self.auth = Auth.auth()
        self.storage = Storage.storage()
        self.firestore = Firestore.firestore()
        
        super.init()
    }
}
