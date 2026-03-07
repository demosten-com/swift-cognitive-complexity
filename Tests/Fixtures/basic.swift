func example(x: Int) -> String {
    if x > 10 {
        for i in 0..<x {
            if i % 2 == 0 {
                print(i)
            }
        }
    } else if x > 5 {
        return "medium"
    } else {
        return "small"
    }
    return "large"
}
