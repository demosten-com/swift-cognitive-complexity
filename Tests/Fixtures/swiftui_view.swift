struct Item {
    let name: String
    let isUrgent: Bool
}

struct ContentView: View {
    @State private var items: [Item] = []
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            VStack {
                if items.isEmpty {              // +1 (if)
                    Text("Empty")
                } else {                        // +1 (else)
                    List {
                        ForEach(items) { item in  // +1 (ForEach)
                            HStack {
                                if item.isUrgent {  // +2 (if, nesting=1 from ForEach)
                                    Image(systemName: "exclamationmark")
                                }
                                Text(item.name)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                DetailView()
            }
        }
    }
}
// Expected total: 7 (with SwiftUI-aware mode)
// if(+1) + else(+1) + ForEach(+2, nesting=1 from if) + if(+3, nesting=2) = 7
