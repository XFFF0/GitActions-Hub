import SwiftUI

// MARK: - Models
struct VideoItem: Identifiable {
    let id: String
    let arTitle: String
    let enTitle: String
    let imgUrl: String
    let kind: String
    let year: String
    let rating: String
}

// MARK: - Colors
extension Color {
    static let cinemaBackground = Color(red: 0.031, green: 0.098, blue: 0.157)  // #081928
    static let cinemaRed = Color(red: 0.784, green: 0.129, blue: 0.153)         // #C82127
    static let cinemaGray = Color(red: 0.847, green: 0.851, blue: 0.847)        // #D8D9D8
}

// MARK: - API Service
class CinemanaAPI: ObservableObject {
    static let baseURL = "https://cinemana.shabakaty.cc/api/android"

    @Published var homeGroups: [HomeGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    struct HomeGroup: Identifiable {
        let id: String
        let arTitle: String
        let enTitle: String
        var videos: [VideoItem]
    }

    func fetchHomeGroups(language: String = "1", parentalLevel: String = "0") {
        isLoading = true
        errorMessage = nil

        let urlStr = "\(Self.baseURL)/videoGroups/lang/\(language)/level/\(parentalLevel)"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let groups = json["videoGroups"] as? [[String: Any]] else {
                    self?.errorMessage = "تعذر تحميل البيانات"
                    return
                }

                self?.homeGroups = groups.compactMap { group -> HomeGroup? in
                    guard let id = group["listId"] as? String else { return nil }
                    let arTitle = group["arTitle"] as? String ?? ""
                    let enTitle = group["enTitle"] as? String ?? ""
                    let videos = (group["videos"] as? [[String: Any]] ?? []).compactMap { v -> VideoItem? in
                        guard let nb = v["nb"] as? String else { return nil }
                        return VideoItem(
                            id: nb,
                            arTitle: v["arTitle"] as? String ?? "",
                            enTitle: v["enTitle"] as? String ?? "",
                            imgUrl: v["imgMediumThumbObjUrl"] as? String ?? "",
                            kind: v["kind"] as? String ?? "movie",
                            year: v["year"] as? String ?? "",
                            rating: v["rate"] as? String ?? "0"
                        )
                    }
                    return HomeGroup(id: id, arTitle: arTitle, enTitle: enTitle, videos: videos)
                }
            }
        }.resume()
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var api = CinemanaAPI()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("الرئيسية", systemImage: "house.fill")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("بحث", systemImage: "magnifyingglass")
                }
                .tag(1)

            CategoriesView()
                .tabItem {
                    Label("الأصناف", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("حسابي", systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(.cinemaRed)
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Home View
struct HomeView: View {
    @StateObject private var api = CinemanaAPI()

    var body: some View {
        NavigationView {
            ZStack {
                Color.cinemaBackground.ignoresSafeArea()

                if api.isLoading {
                    VStack(spacing: 16) {
                        CinemanaLogo(size: 80)
                        ProgressView()
                            .tint(.cinemaRed)
                        Text("جاري التحميل...")
                            .foregroundColor(.cinemaGray)
                            .font(.caption)
                    }
                } else if let error = api.errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.cinemaRed)
                        Text(error)
                            .foregroundColor(.cinemaGray)
                            .multilineTextAlignment(.center)
                        Button("إعادة المحاولة") {
                            api.fetchHomeGroups()
                        }
                        .buttonStyle(CinemanaButtonStyle())
                    }
                    .padding()
                } else if api.homeGroups.isEmpty {
                    WelcomeView()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .trailing, spacing: 24) {
                            ForEach(api.homeGroups) { group in
                                VideoGroupSection(group: group)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CinemanaLogo(size: 32)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.cinemaGray)
                    }
                }
            }
        }
        .onAppear { api.fetchHomeGroups() }
    }
}

// MARK: - Welcome View (shown when no data yet)
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            CinemanaLogo(size: 120)

            VStack(spacing: 8) {
                Text("سينمانا")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                Text("اكتشف أفضل الأفلام والمسلسلات العربية")
                    .font(.body)
                    .foregroundColor(.cinemaGray)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                NavigationLink(destination: LoginView()) {
                    Text("تسجيل الدخول")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cinemaRed)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.headline)
                }

                Button(action: {}) {
                    Text("تصفح بدون تسجيل")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cinemaGray.opacity(0.5), lineWidth: 1)
                        )
                        .foregroundColor(.cinemaGray)
                        .font(.headline)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Video Group Section
struct VideoGroupSection: View {
    let group: CinemanaAPI.HomeGroup

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Button(action: {}) {
                    Text("عرض الكل")
                        .font(.caption)
                        .foregroundColor(.cinemaRed)
                }
                Spacer()
                Text(group.arTitle.isEmpty ? group.enTitle : group.arTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.videos) { video in
                        NavigationLink(destination: VideoDetailView(video: video)) {
                            VideoCard(video: video)
                        }
                    }
                }
                .padding(.horizontal)
                .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}

// MARK: - Video Card
struct VideoCard: View {
    let video: VideoItem

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            AsyncImage(url: URL(string: video.imgUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.cinemaRed.opacity(0.3))
                        .overlay(Image(systemName: "film").foregroundColor(.cinemaRed))
                default:
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .overlay(ProgressView().tint(.cinemaRed))
                }
            }
            .frame(width: 130, height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(video.arTitle.isEmpty ? video.enTitle : video.arTitle)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(width: 130, alignment: .trailing)

            HStack(spacing: 4) {
                Text(video.year)
                    .font(.caption2)
                    .foregroundColor(.cinemaGray)
                Spacer()
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text(video.rating)
                    .font(.caption2)
                    .foregroundColor(.cinemaGray)
            }
            .frame(width: 130)
        }
    }
}

// MARK: - Search View
struct SearchView: View {
    @State private var query = ""
    @State private var results: [VideoItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.cinemaBackground.ignoresSafeArea()
                VStack {
                    HStack {
                        Button(action: performSearch) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.cinemaRed)
                        }
                        TextField("ابحث عن فيلم أو مسلسل...", text: $query)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                            .onSubmit { performSearch() }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding()

                    if isSearching {
                        ProgressView().tint(.cinemaRed).padding()
                        Spacer()
                    } else if results.isEmpty && !query.isEmpty {
                        Spacer()
                        Text("لا توجد نتائج لـ \"\(query)\"")
                            .foregroundColor(.cinemaGray)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(results) { video in
                                    NavigationLink(destination: VideoDetailView(video: video)) {
                                        VideoCard(video: video)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("بحث")
        }
    }

    func performSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr = "https://cinemana.shabakaty.cc/api/android/AdvancedSearch?videoTitle=\(encoded)&page=1&level=0"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isSearching = false
                guard let data = data,
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
                results = arr.compactMap { v in
                    guard let nb = v["nb"] as? String else { return nil }
                    return VideoItem(id: nb,
                                   arTitle: v["arTitle"] as? String ?? "",
                                   enTitle: v["enTitle"] as? String ?? "",
                                   imgUrl: v["imgMediumThumbObjUrl"] as? String ?? "",
                                   kind: v["kind"] as? String ?? "",
                                   year: v["year"] as? String ?? "",
                                   rating: v["rate"] as? String ?? "0")
                }
            }
        }.resume()
    }
}

// MARK: - Categories View
struct CategoriesView: View {
    @State private var categories: [(id: String, arTitle: String, enTitle: String)] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                Color.cinemaBackground.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.cinemaRed)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(categories, id: \.id) { cat in
                                Button(action: {}) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.cinemaRed.opacity(0.15))
                                            .frame(height: 70)
                                        Text(cat.arTitle.isEmpty ? cat.enTitle : cat.arTitle)
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("الأصناف")
            .onAppear(perform: fetchCategories)
        }
    }

    func fetchCategories() {
        guard let url = URL(string: "https://cinemana.shabakaty.cc/api/android/categories") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data,
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
                categories = arr.compactMap { c in
                    guard let id = c["nb"] as? String else { return nil }
                    return (id: id,
                            arTitle: c["arTitle"] as? String ?? "",
                            enTitle: c["enTitle"] as? String ?? "")
                }
            }
        }.resume()
    }
}

// MARK: - Profile View
struct ProfileView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.cinemaBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    CinemanaLogo(size: 80)
                    Text("مرحباً بك في سينمانا")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                    Text("سجّل دخولك للوصول إلى مفضلتك وسجل المشاهدة")
                        .foregroundColor(.cinemaGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    NavigationLink(destination: LoginView()) {
                        Text("تسجيل الدخول")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cinemaRed)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .font(.headline)
                    }
                    .padding(.horizontal, 32)
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("حسابي")
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMsg = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cinemaBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                CinemanaLogo(size: 80)
                    .padding(.top, 20)

                Text("تسجيل الدخول")
                    .font(.title).bold()
                    .foregroundColor(.white)

                VStack(spacing: 16) {
                    CinemanaTextField(placeholder: "اسم المستخدم أو البريد", text: $username)
                    CinemanaTextField(placeholder: "كلمة المرور", text: $password, isSecure: true)
                }
                .padding(.horizontal)

                if !errorMsg.isEmpty {
                    Text(errorMsg)
                        .foregroundColor(.cinemaRed)
                        .font(.caption)
                }

                Button(action: performLogin) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("دخول")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cinemaRed)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(isLoading)

                Button("هل نسيت كلمة المرور؟") {}
                    .foregroundColor(.cinemaGray)
                    .font(.footnote)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    func performLogin() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMsg = "يرجى ملء جميع الحقول"
            return
        }
        isLoading = true
        errorMsg = ""

        // POST to identity server
        guard let url = URL(string: "https://account.shabakaty.cc/core/connect/token") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Basic auth: clientId:secret in base64
        let credentials = "cTnj9bUcDmr08B586K7pGFHy:secret"
        let b64 = Data(credentials.utf8).base64EncodedString()
        req.setValue("Basic \(b64)", forHTTPHeaderField: "Authorization")

        let body = "username=\(username)&password=\(password)&scope=openid%20email%20offline_access&grant_type=password"
        req.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, resp, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMsg = error.localizedDescription; return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    errorMsg = "حدث خطأ، حاول مجدداً"; return
                }
                if let token = json["access_token"] as? String {
                    UserDefaults.standard.set(token, forKey: "access_token")
                    dismiss()
                } else {
                    errorMsg = json["error_description"] as? String ?? "فشل تسجيل الدخول"
                }
            }
        }.resume()
    }
}

// MARK: - Video Detail View
struct VideoDetailView: View {
    let video: VideoItem
    @State private var transcodeFiles: [(name: String, resolution: String, url: String)] = []

    var body: some View {
        ZStack {
            Color.cinemaBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .trailing, spacing: 20) {
                    AsyncImage(url: URL(string: video.imgUrl)) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle().fill(Color.cinemaRed.opacity(0.2)).frame(height: 250)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipped()

                    VStack(alignment: .trailing, spacing: 12) {
                        Text(video.arTitle.isEmpty ? video.enTitle : video.arTitle)
                            .font(.title2).bold()
                            .foregroundColor(.white)

                        HStack(spacing: 16) {
                            Label(video.rating, systemImage: "star.fill")
                                .foregroundColor(.yellow).font(.caption)
                            Text(video.year).foregroundColor(.cinemaGray).font(.caption)
                            Text(video.kind == "series" ? "مسلسل" : "فيلم")
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.cinemaRed.opacity(0.2))
                                .foregroundColor(.cinemaRed)
                                .cornerRadius(6).font(.caption)
                        }

                        if !transcodeFiles.isEmpty {
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("جودات المشاهدة")
                                    .font(.headline).foregroundColor(.white)
                                ForEach(transcodeFiles, id: \.url) { file in
                                    Button(action: { openVideo(url: file.url) }) {
                                        HStack {
                                            Spacer()
                                            Text(file.resolution + "p")
                                                .font(.subheadline).foregroundColor(.cinemaRed)
                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(.cinemaRed)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: fetchTranscode)
    }

    func fetchTranscode() {
        guard let url = URL(string: "https://cinemana.shabakaty.cc/api/android/transcoddedFiles/id/\(video.id)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
                transcodeFiles = arr.compactMap { f in
                    guard let u = f["videoUrl"] as? String else { return nil }
                    return (name: f["name"] as? String ?? "",
                            resolution: f["resolution"] as? String ?? "?",
                            url: u)
                }
            }
        }.resume()
    }

    func openVideo(url: String) {
        guard let u = URL(string: url) else { return }
        UIApplication.shared.open(u)
    }
}

// MARK: - Shared Components

struct CinemanaLogo: View {
    let size: CGFloat
    var body: some View {
        Image("AppIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

struct CinemanaTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .foregroundColor(.white)
        .cornerRadius(12)
        .multilineTextAlignment(.trailing)
    }
}

struct CinemanaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.cinemaRed)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
