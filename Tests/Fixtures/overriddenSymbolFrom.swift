func overriddenSymbolFrom(
    _ classOrProtocol: Any,
    forName name: String,
    types: [Any]
) -> Any? {
    if let klass = classOrProtocol as? String {       // +1 (if, nesting=0)
        for type in types {                           // +2 (for, nesting=1)
            if let method = type as? String {         // +3 (if, nesting=2)
                if method == name {                   // +4 (if, nesting=3)
                    if isOverriding(method) {         // +5 (if, nesting=4)
                        return method
                    }
                }
            }
        }
        if let parent = getParent(klass) {            // +2 (if, nesting=1)
            return overriddenSymbolFrom(              // +1 (recursion)
                parent, forName: name, types: types
            )
        }
    } else {                                          // +1 (else)
        // protocol case — not handled
    }
    return nil
}

// Helper stubs for compilation
func isOverriding(_ method: String) -> Bool { return false }
func getParent(_ klass: String) -> String? { return nil }
func overriddenSymbolFrom(_ parent: String, forName name: String, types: [Any]) -> Any? { return nil }
// Expected: 19 (1+2+3+4+5+2+1+1)
