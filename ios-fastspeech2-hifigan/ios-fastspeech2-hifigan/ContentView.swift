//
//  ContentView.swift
//  ios-fastspeech2-hifigan
//
//  Created by Yasuo Hasegawa on 2025/07/14.
//

import SwiftUI

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = OpenJTalkViewModel()
    @State private var inputText:String = """
    伝説の選手たちの足元を支えた"KING"がストリートへ！
    サッカーの歴史を彩ってきた伝説の名手たち。その足元で、常に王者の輝きを放ってきたのが、"PUMA(プーマ)"が誇る名作スパイク、"KING(キング)"。"PELÉ(ペレ)"、"JOHAN CRUYFF(ヨハン・クライフ)"、"DIEGO MARADONA(ディエゴ・マラドーナ)"、神々と称された男たちが愛用したそのスパイクのDNAを受け継ぎ、ストリート仕様へと昇華された"KING INDOOR(キング インドア)"が、クラシックな装いで復活。元々はインドアトレーニング用に開発された"KING INDOOR"だが、その快適な履き心地と、折り返しのシュータンが象徴するクラシックなルックスは、ピッチの外でも支持を集める。フットサルコートから、英国の"テラスカルチャー"まで、そのフィールドを拡大。近年、"ブロークコア"のレトロなスポーツミックススタイルがトレンドとなる中、そのオーセンティックな魅力が再評価され、ファッションシーンでも注目度が高まっている。
    本作は、ヴィンテージ感漂うブラックのレザーアッパーに、ワイドなキルティングステッチを施した、クラシックな佇まい。サイドを駆け抜けるホワイトのフォームストリップのエッジとそして折り返しタンのトリムには、アルゼンチン代表を彷彿とさせる、鮮やかなライトブルーが差し込まれている。ヒールにはプーマキャットと共に、伝説的なプレーヤーたちが背負ったナンバー"10"をプリント。まるでプレイ後の譲土加工を施したミッドソールと、飴色のガムソールがノスタルジックな雰囲気を醸し出す。
    """
    
    @State private var phoneme:String = ""
    
    var body: some View {
        VStack {
            Button(action: {
                viewModel.speakWithOpenJTalk(text: inputText)
            }) {
                Text("Speak with OpenJTalk")
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Button(action: {
                DispatchQueue.main.async {
                    phoneme = viewModel.extractPhoneme(text: inputText)
                }
            }) {
                Text("Extract the phoneme from text")
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Text(phoneme)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
