//
//  LoginView.swift
//  Major Project
//
//  Created by Ujjwal Chopra on 12/09/23.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

struct LoginView: View {
    
    @State private var isLoginMode = false
    @State private var email = ""
    @State private var password = ""
    @State var loginStatusMessage = ""
    @State var shouldShowImagePicker = false
    let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .red]
    
    let didCompleteLoginProcess: () -> ()
    
    var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        Picker(selection: $isLoginMode, label: Text("Picker here")) {
                            Text("Login")
                                .tag(true)
                            Text("Register")
                                .tag(false)
                        }.pickerStyle(SegmentedPickerStyle())
                            
                        if !isLoginMode {
                            Button {
                                shouldShowImagePicker.toggle()
                            } label: {
                                
                                VStack {
                                    if let image = self.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 128, height: 128)
                                            .cornerRadius(64)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 64))
                                            .padding()
                                            .foregroundColor(Color(.label))
                                    }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 64)
                                            .stroke(Color.black, lineWidth: 3)
                                )
                                
                            }
                        }
                        
                        Group {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            SecureField("Password", text: $password)
                        }
                        .padding(12)
                        .background(Color.white)
                        
                        Button {
                            handleAction()
                        } label: {
                            HStack {
                                Spacer()
                                Text(isLoginMode ? "Log In" : "Register")
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }.background(Color.blue)
                        }
                        
                        Text(self.loginStatusMessage)
                            .foregroundColor(.red)
                    }
                    .padding()
                    
                }
                .navigationTitle(isLoginMode ? "Log In" : "Register")
                .background(Color(red:0.9725 , green: 1.00, blue:0.4313 ).ignoresSafeArea())
                
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
                ImagePicker(isPresented: $shouldShowImagePicker, image: $image)
            }
        }
    
    
    @State var image: UIImage?
    
    private func handleAction() {
        if isLoginMode {
            loginUser()
        } else {
            createUser()
        }
    }
    
    private func createUser(){
        
        if self.image == nil {
            self.loginStatusMessage = "You must select an avatar image"
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) {
            authResult, error in
            if let e = error {
                self.loginStatusMessage = "Failed to create user: \(e.localizedDescription)"
                print(e.localizedDescription)
            } else{
                print("Successfully logged in as user: \(authResult?.user.uid ?? "") ")
                self.loginStatusMessage = "Successfully registered as user: \(authResult?.user.uid ?? "") "
                
                self.persistImageToStorage()
//              MainMessagesView()
            }
        }

    }
        
    private func persistImageToStorage() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Storage.storage().reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else { return }
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                self.loginStatusMessage = "Failed to push image to Storage: \(err)"
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    self.loginStatusMessage = "Failed to retrieve downloadURL: \(err)"
                    return
                }
                
                self.loginStatusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                print(url?.absoluteString ?? "")
                guard let url = url else { return }
                self.storeUserInformation(imageProfileUrl: url)
            }
        }
    }
    
    private func storeUserInformation(imageProfileUrl:URL){
        let db = Firestore.firestore()
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let userData = ["email": self.email, "uid": uid, "profileImageUrl": imageProfileUrl.absoluteString] as [String : Any]
        
        db.collection("users")
            .document(uid).setData(userData) { err in
                if let err = err {
                    print("\(err)")
                    return
                }
                
                print("Success")
                self.didCompleteLoginProcess()
        }
        
    }
    
    private func loginUser(){
        Auth.auth().signIn(withEmail: email, password: password) {  authResult, error in
            if let e = error {
                print(e.localizedDescription)
                self.loginStatusMessage = "Failed to create user: \(e)"
            } else {
                
                print("Successfully logged in as user\(authResult?.user.uid ?? "") ")
                self.loginStatusMessage = "Successfully logged in as user\(authResult?.user.uid ?? "") "
                self.didCompleteLoginProcess()
                MainMessagesView()
            }
        }
    }
}


struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(didCompleteLoginProcess: {
        })
//        MainMessagesView()
    }
}
