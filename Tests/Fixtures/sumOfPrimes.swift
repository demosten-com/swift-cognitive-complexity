func sumOfPrimes(max: Int) -> Int {
    var total = 0
    OUT: for i in 1...max {                      // +1 (for)
        for j in 2..<i {                         // +2 (for, nesting=1)
            if i % j == 0 {                      // +3 (if, nesting=2)
                continue OUT                     // +1 (labeled continue)
            }
        }
        total += i
    }
    return total
}
// Expected: 7
