func getWords(_ number: Int) -> String {
    switch number {                              // +1 (switch)
    case 1:
        return "one"
    case 2:
        return "a couple"
    case 3:
        return "a few"
    default:
        return "lots"
    }
}
// Expected: 1
