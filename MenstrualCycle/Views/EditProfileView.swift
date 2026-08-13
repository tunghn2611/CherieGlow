//
//  EditProfileView.swift
//  MenstrualCycle
//
//  Màn hình Chỉnh sửa hồ sơ.
//  Cho phép thay đổi ảnh đại diện, tên hiển thị và SĐT.
//  Tương thích iOS 15+.
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editName: String = ""
    @State private var editPhone: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Interactive Avatar
                    Button(action: {
                        showImagePicker = true
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: Color.gradientPink),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    
                                if let img = selectedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let avatar = authViewModel.currentUserAvatar {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Circle()
                                .fill(Color.creamWhite)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                        .foregroundColor(.dustyRose)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 16) {
                        inputField(icon: "person.fill", placeholder: "Tên hiển thị", text: $editName)
                        inputField(icon: "phone.fill", placeholder: "Số điện thoại", text: $editPhone)
                    }
                    .pastelCard()
                    
                    // Save Button
                    Button(action: {
                        saveChanges()
                    }) {
                        Text("Lưu thay đổi")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: Color.gradientPink),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.dustyRose.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.softPink.ignoresSafeArea())
            .navigationTitle("Chỉnh sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.body.bold())
                    }
                    .foregroundColor(.dustyRose)
                    .buttonStyle(.plain)
                }
            }
            .onAppear {
                editName = authViewModel.currentUserName
                editPhone = authViewModel.currentUserPhone
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    private func inputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.dustyRose)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color.softPink)
        .cornerRadius(12)
    }

    private func saveChanges() {
        guard let userId = authViewModel.currentUserId else { return }
        
        // Cập nhật Avatar nếu có chọn ảnh mới
        var avatarPath = authViewModel.currentUserAvatarPath
        if let img = selectedImage {
            if let savedPath = AvatarHelper.saveAvatar(img, userId: userId) {
                avatarPath = savedPath
                let _ = UserRepository().updateAvatar(userId: userId, avatarPath: avatarPath)
            }
        }
        
        // Cập nhật Tên và SĐT vào SQLite
        let success = UserRepository().updateUser(userId: userId, name: editName, phone: editPhone)
        
        if success {
            // Nạp lại thông tin mới nhất vào AuthViewModel
            if let userInfo = UserRepository().fetchUser(byId: userId) {
                authViewModel.currentUserName = userInfo.name
                authViewModel.currentUserPhone = userInfo.phone
                authViewModel.currentUserAvatarPath = userInfo.avatarPath
                if !userInfo.avatarPath.isEmpty {
                    authViewModel.currentUserAvatar = AvatarHelper.loadAvatar(fileName: userInfo.avatarPath)
                }
            }
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
            .environmentObject(AuthViewModel())
    }
}
