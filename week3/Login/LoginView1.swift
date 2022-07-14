//
//  LoginView1.swift
//  week3
//
//  Created by 남유성 on 2022/07/14.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

struct LoginView1: View {
    
    @State private var loginType: String = "needLogin"
    
    var body: some View {
        if (loginType == "needLogin") {
            Text("LoginView")
            Button {
                // 카카오톡 설치 여부
                if (UserApi.isKakaoTalkLoginAvailable()) {
                    // 카카오톡으로 로그인
                    UserApi.shared.loginWithKakaoTalk {(oauthToken, error) in
                        if let error = error {
                            print("⛔️ can not login with Kakao")
                            print(error)
                        } else {
                            print("✅ loginWithKakaoTalk() success")
                            loginType = "LogInWithKakao"
                        }
                    }
                } else {
                    // 카카오 계정으로 로그인
                    UserApi.shared.loginWithKakaoAccount { (oauthToken, error) in
                        if let error = error {
                            print("⛔️ can not login with KakaoAcount")
                            print(error)
                        } else {
                            print("✅ loginWithKakaoTalkAccount() success")
                            loginType = "LogInWithKakao"
                        }
                    }
                }
            } label: {
                Text("kakao Login")
            }
        } else {
            MainView1()
        }
    }
}

struct LoginView1_Previews: PreviewProvider {
    static var previews: some View {
        LoginView1()
    }
}
