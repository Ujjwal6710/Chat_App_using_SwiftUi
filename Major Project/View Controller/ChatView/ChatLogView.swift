//
//  ChatLogView.swift
//  Major Project
//
//  Created by Ujjwal Chopra on 03/10/23.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    
    var chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        
        fetchMessages()
    }
    
    var firestoreListener: ListenerRegistration?
    func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        firestoreListener?.remove()
        chatMessages.removeAll()
        
        // Add a listener to the sender's chat messages collection
        let senderMessagesCollection = FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .order(by: FirebaseConstants.timestamp)
        
        firestoreListener = senderMessagesCollection.addSnapshotListener { querySnapshot, error in
            if let error = error {
                self.errorMessage = "Failed to listen for messages: \(error)"
                print(error)
                return
            }
            
            querySnapshot?.documentChanges.forEach { change in
                switch change.type {
                case .added:
                    do {
                        let cm = try change.document.data(as: ChatMessage.self)
                        if cm.text.lowercased() != "delete" {
                            self.chatMessages.append(cm)
                            print("Appending chatMessage in ChatLogView: \(Date())")
                        }
                    } catch {
                        print("Failed to decode message: \(error)")
                    }
                case .modified: break
                    // Handle modifications (if needed)
                case .removed:
                    // Handle message removal
                    if let index = self.chatMessages.firstIndex(where: { $0.id == change.document.documentID }) {
                        self.chatMessages.remove(at: index)
                        print("Message Removed from chat screen")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.count += 1
            }
        }
    }
    
    func deleteMessage(_ message: ChatMessage) {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {
            print("User is not authenticated.")
            return
        }
        guard let toId = chatUser?.uid else {
            print("Chat user is missing.")
            return
        }
        
        guard let messageId = message.id else {
            print("Message ID is missing.")
            return
        }
        
        // Delete the message from the sender's collection
        let senderMessageDocument = FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .document(messageId)
        
        senderMessageDocument.delete { error in
            if let error = error {
                print("Failed to delete message from sender's collection: \(error)")
                return
            }
            self.updateRecentMessagesAfterDeletion(message, fromId: fromId, toId: toId)
            print("Message Deleted from sender's collection")
        }
        
        // Delete the message from the recipient's collection
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
            .document(toId)
            .collection(fromId)
            .document(messageId)
        
        recipientMessageDocument.delete { error in
            if let error = error {
                print("Failed to delete message from recipient's collection: \(error)")
                return
            }
            self.updateRecentMessagesAfterDeletion(message , fromId: fromId, toId: toId)
            print("Message Deleted from recipient's collection")
        }
        
        // Delete the message from recent messages
        if let fromId = FirebaseManager.shared.auth.currentUser?.uid,
           let toId = chatUser?.uid {
            let recentMessageDocument = FirebaseManager.shared.firestore.collection(FirebaseConstants.recentMessages)
                .document(fromId)
                .collection(FirebaseConstants.messages)
                .document(toId)
            
            recentMessageDocument.delete { error in
                if let error = error {
                    print("Failed to delete message from recent messages: \(error)")
                    return
                }
                print("Message Deleted from recent messages")
            }
        }
        
        // Remove the message from the local chatMessages array
        if let index = self.chatMessages.firstIndex(where: { $0.id == message.id }) {
            self.chatMessages.remove(at: index)
        }
    }
    
    
    func updateRecentMessagesAfterDeletion(_ message: ChatMessage, fromId: String, toId: String) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        let deleteMessageText = "Message was deleted"
        
        // Update recent messages for the sender
        let senderDocument = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(uid)
            .collection(FirebaseConstants.messages)
            .document(toId)
        
        let senderData: [String: Any] = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: deleteMessageText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser?.profileImageUrl ?? "",
            FirebaseConstants.email: chatUser?.email ?? ""
        ]
        
        senderDocument.setData(senderData) { error in
            if let error = error {
                self.errorMessage = "Failed to update recent message for the sender: \(error)"
                print("Failed to update recent message for the sender: \(error)")
            }
        }
        
        // Update recent messages for the recipient
        let recipientDocument = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(toId)
            .collection(FirebaseConstants.messages)
            .document(fromId)
        
        let recipientData: [String: Any] = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: deleteMessageText,
            FirebaseConstants.fromId: toId,
            FirebaseConstants.toId: uid,
            FirebaseConstants.profileImageUrl: chatUser?.profileImageUrl ?? "",
            FirebaseConstants.email: chatUser?.email ?? ""
        ]
        
        recipientDocument.setData(recipientData) { error in
            if let error = error {
                self.errorMessage = "Failed to update recent message for the recipient: \(error)"
                print("Failed to update recent message for the recipient: \(error)")
            }
        }
    }
    
    func handleSend() {
        print(chatText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        guard let toId = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [ FirebaseConstants.fromId: fromId, FirebaseConstants.toId: toId, FirebaseConstants.text: self.chatText, FirebaseConstants.timestamp: Timestamp()] as [String : Any]
        
        
        document.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            
            print("Successfully saved current user sending message")
            
            self.persistRecentMessage()
            
            self.chatText = ""
            self.count += 1
        }
        
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            
            print("Recipient saved message as well")
        }
    }
    
    private func persistRecentMessage() {
        guard let chatUser = chatUser else { return }
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(uid)
            .collection(FirebaseConstants.messages)
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
            FirebaseConstants.email: chatUser.email
        ] as [String : Any]
        
        // you'll need to save another very similar dictionary for the recipient of this message...how?
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message: \(error)"
                print("Failed to save recent message: \(error)")
                return
            }
        }
        
        guard let currentUser = FirebaseManager.shared.currentUser else { return }
        let recipientRecentMessageDictionary = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: currentUser.profileImageUrl,
            FirebaseConstants.email: currentUser.email
        ] as [String : Any]
        
        FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(toId)
            .collection(FirebaseConstants.messages)
            .document(currentUser.uid)
            .setData(recipientRecentMessageDictionary) { error in
                if let error = error {
                    print("Failed to save recipient recent message: \(error)")
                    return
                }
            }
    }
    @Published var count = 0
}

struct ChatLogView: View {
    
    let chatUser: ChatUser?
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        self.vm = .init(chatUser: chatUser)
    }
    
    @ObservedObject var vm: ChatLogViewModel
    
    var body: some View {
        
        ZStack {
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            vm.firestoreListener?.remove()
        }
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View {
        VStack {
            if #available(iOS 15.0, *) {
                ScrollView {
                    ScrollViewReader { scrollViewProxy in
                        VStack {
                            ForEach(vm.chatMessages) { message in
                                MessageView(message: message, vm: vm)
                            }
                            HStack{ Spacer() }
                                .id(Self.emptyScrollToString)
                        }
                        .onReceive(vm.$count) { _ in
                            withAnimation(.easeOut(duration: 0.5)) {
                                scrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.init(white: 0.95, alpha: 1)))
                .safeAreaInset(edge: .bottom) {
                    chatBottomBar
                        .background(Color(.systemBackground).ignoresSafeArea())
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    private var chatBottomBar: some View {
        
        HStack(spacing: 16) {
            
            ZStack {
                DescriptionPlaceholder()
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct MessageView: View {
    
    let message: ChatMessage
    
    @State var isDeleteButtonVisible = false
    @ObservedObject var vm: ChatLogViewModel
    
    var body: some View {
        VStack {
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
                HStack {
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                HStack {
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .gesture(longPressGesture)
        .overlay(deleteButton, alignment: .topTrailing)
    }
    
    var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 2.0)
            .onChanged { _ in
                isDeleteButtonVisible = true
            }
            .onEnded { _ in
                isDeleteButtonVisible = false
            }
    }
    
    var deleteButton: some View {
        if isDeleteButtonVisible {
            return AnyView(Button(action: {
                vm.deleteMessage(message)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
            })
        } else {
            return AnyView(EmptyView())
        }
    }
}

private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Description")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
    }
}
