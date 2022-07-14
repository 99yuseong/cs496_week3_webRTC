//
//  LoginView.swift
//  week3
//
//  Created by 남유성 on 2022/07/14.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

struct LoginView2: View {
    
    
    var body: some View {
        Button {
            // 카카오톡 설치 여부 확인
            if (UserApi.isKakaoTalkLoginAvailable()) {
                // 앱 설치 시, 카카오톡 앱으로 로그인
                UserApi.shared.loginWithKakaoTalk {(oauthToken, error) in
                    if let error = error {
                        print("⛔️ can not login with Kakao")
                        print(error)
                    }
                    else {
                        print("✅ loginWithKakaoTalk() success")
                        //do something
                        print(oauthToken!)
                    }
                }
            } else {
                // 앱 설치하지 않았을 시, 카카오 계정으로 로그인
                UserApi.shared.loginWithKakaoAccount { (oauthToken, error) in
                    if let error = error {
                        print("⛔️ can not login with KakaoAcount")
                        print(error)
                    } else {
                        print("✅ loginWithKakaoTalkAccount() success")
                        print(oauthToken!)
                    }
                }

            }
        } label: {
            Image("kakao_login_medium_wide_ko")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.width * 0.8)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView2()
    }
}
