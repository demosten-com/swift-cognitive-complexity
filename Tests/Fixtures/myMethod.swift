func myMethod() {
    do {
        if condition1 {                          // +1 (if)
            for i in 0..<10 {                    // +2 (for, nesting=1)
                while condition2 {               // +3 (while, nesting=2)
                    // ...
                }
            }
        }
    } catch {                                    // +1 (catch)
        if condition3 {                          // +2 (if, nesting=1)
            // ...
        }
    }
}
// Expected: 9
