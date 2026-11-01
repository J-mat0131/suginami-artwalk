import Foundation
import CoreLocation

/// アートサイン1か所分のデータ。
/// 出典: 杉並区公式ホームページ「すぎなみアートウォーク」各設置場所ページ（2026年9月15日更新）。
/// コンセプト文は公式ページの要旨を本アプリ用に短く言い換えたもの。全文は officialURL を参照。
struct ArtSign: Identifiable, Hashable {
    let id: Int              // 推奨巡回順（1〜7）
    let place: String        // 設置場所
    let shortPlace: String   // 地図ピン用の短い名前
    let area: Area
    let title: String        // 作品タイトル
    let artist: String       // アーティスト名
    let summary: String      // コンセプト要旨（言い換え）
    let motifs: [String]     // 見どころのキーワード
    let latitude: Double
    let longitude: Double
    let pageID: Int          // 区公式ページID

    enum Area: String {
        case asagaya = "阿佐谷"
        case koenji = "高円寺"
    }

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        .init(latitude: latitude, longitude: longitude)
    }

    var officialURL: URL {
        URL(string: "https://www.city.suginami.tokyo.jp/s092/\(pageID).html")!
    }

    static func == (l: ArtSign, r: ArtSign) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension ArtSign {
    /// 阿佐ケ谷駅から反時計回りに一周する推奨順。
    static let all: [ArtSign] = [
        ArtSign(
            id: 1,
            place: "阿佐ケ谷駅南口駅前広場",
            shortPlace: "阿佐ケ谷駅南口",
            area: .asagaya,
            title: "星降る街の即興詩",
            artist: "女子美術大学デザインルーム 和田歩実",
            summary: "阿佐谷七夕まつりと阿佐谷ジャズストリート、夏の二つの風物詩をひとつに重ねた作品。ピアノの鍵盤を天の川に見立て、楽器と笹飾りが夜空の下でセッションしているような華やかさを描いています。",
            motifs: ["ピアノの鍵盤＝天の川", "トランペット・コントラバス", "笹飾りと吹き流し"],
            latitude: 35.70447811538044, longitude: 139.63642663477202,
            pageID: 27857
        ),
        ArtSign(
            id: 2,
            place: "阿佐ヶ谷児童遊園",
            shortPlace: "阿佐ヶ谷児童遊園",
            area: .asagaya,
            title: "本から広がる世界",
            artist: "女子美術大学デザインルーム 福居わかば",
            summary: "「本」を軸に、絵本を開いたような空想の世界を表現。花畑の花々には平和や調和の願いが込められ、公園が地域の安心できる居場所であり続けるよう祈った一枚です。",
            motifs: ["本の形をした蝶", "デイジー・黄色のバラ・コスモス", "読書する子ども"],
            latitude: 35.70047388777755, longitude: 139.63764814839192,
            pageID: 27859
        ),
        ArtSign(
            id: 3,
            place: "阿佐谷にしはら公園",
            shortPlace: "にしはら公園",
            area: .asagaya,
            title: "緑と生きるまち",
            artist: "女子美術大学デザインルーム 石川茉央",
            summary: "住宅地に息づく多様な植物と、木漏れ日のやわらかな光が主役。家並みや遊具、鳥も描き込み、自然と暮らしが溶け合う何気ない日常の美しさに目を向けさせてくれます。",
            motifs: ["中央に差し込む光", "さまざまな草木", "住宅と遊具"],
            latitude: 35.69982211816476, longitude: 139.64184943321328,
            pageID: 27860
        ),
        ArtSign(
            id: 4,
            place: "桃園川緑道",
            shortPlace: "桃園川緑道",
            area: .asagaya,
            title: "桃から繋がる物語",
            artist: "女子美術大学デザインルーム 水谷彩良",
            summary: "かつて流れた桃園川の名の由来「桃」から桃太郎を連想し、猿・犬・キジを登場させた作品。桃から生まれた川が今の緑道へ続く構図で、土地の記憶と現在の風景をつないでいます。",
            motifs: ["桃から流れ出す川", "猿・犬・キジ", "筆跡を残したコラージュ"],
            latitude: 35.70362264392193, longitude: 139.64480545729063,
            pageID: 27861
        ),
        ArtSign(
            id: 5,
            place: "高円寺中央公園",
            shortPlace: "高円寺中央公園",
            area: .koenji,
            title: "“好き”が響くまち",
            artist: "女子美術大学デザインルーム 石川茉央",
            summary: "音楽を中心に多様なカルチャーが混ざり合う高円寺らしさを、レコードの上で思い思いに過ごす人々で表現。楽器を奏でる人、本を読む人、踊る人、それぞれの「好き」が響き合います。",
            motifs: ["レコードの上の人々", "ギター・トランペット", "弾けるような色彩"],
            latitude: 35.70384137646024, longitude: 139.65178558398446,
            pageID: 27863
        ),
        ArtSign(
            id: 6,
            place: "馬橋公園",
            shortPlace: "馬橋公園",
            area: .koenji,
            title: "木の下で、のびのびと",
            artist: "女子美術大学デザインルーム 福居わかば",
            summary: "テーマは「開放感」。広い緑の中で体を動かす人々に、水遊び場のしぶきと幸せを運ぶとされるツバメを添え、公園で健やかに過ごしてほしいという願いを込めています。",
            motifs: ["水遊び場の水しぶき", "空を舞うツバメ", "草地広場でくつろぐ人"],
            latitude: 35.70977688772627, longitude: 139.64416284904436,
            pageID: 27866
        ),
        ArtSign(
            id: 7,
            place: "阿佐谷地域区民センター（阿佐谷けやき公園）",
            shortPlace: "阿佐谷けやき公園",
            area: .asagaya,
            title: "欅と共に育つ街",
            artist: "女子美術大学デザインルーム 丸山菜乃",
            summary: "屋上から見た広い空、大きく枝を広げる欅、連なる住宅街の三つを重ねた作品。欅が街を包み込みながら共に育っていく姿に、人が自然と集うおおらかな時間を描いています。",
            motifs: ["枝を広げる欅", "遠くの新宿の高層ビル", "行き交う電車"],
            latitude: 35.705532542051564, longitude: 139.64111240427113,
            pageID: 27867
        ),
    ]
}

/// イベント全体の情報。
enum ArtWalkEvent {
    static let name = "すぎなみアートウォーク"
    static let start = DateComponents(calendar: .init(identifier: .gregorian), timeZone: .init(identifier: "Asia/Tokyo"), year: 2026, month: 10, day: 1).date!
    /// 2027年3月21日 終日まで
    static let end = DateComponents(calendar: .init(identifier: .gregorian), timeZone: .init(identifier: "Asia/Tokyo"), year: 2027, month: 3, day: 21, hour: 23, minute: 59).date!
    static let periodText = "2026年10月1日（木）〜 2027年3月21日（日）"
    static let courseText = "一周 約5〜6km"
    static let officialURL = URL(string: "https://www.city.suginami.tokyo.jp/s092/event/27274.html")!
    static let routeMapPDF = URL(string: "https://www.city.suginami.tokyo.jp/documents/27274/artwalkmap.pdf")!
    static let noveltyPDF = URL(string: "https://www.city.suginami.tokyo.jp/documents/27274/haihu.pdf")!
    static let namichareURL = URL(string: "https://www.suginami-namichare.com/")!
    /// このアプリのサポート・プライバシーポリシー（GitHub Pages）
    static let supportURL = URL(string: "https://j-mat0131.github.io/suginami-artwalk/support/")!
    static let privacyURL = URL(string: "https://j-mat0131.github.io/suginami-artwalk/privacy/")!

    static var isOngoing: Bool {
        let now = Date()
        return now >= start && now <= end
    }
}
